# Open Code Review

This workflow reviews PRs targeting `main` and `deb_source` with Alibaba
OpenCodeReview. It posts Chinese findings and a new summary per review. Low
severity findings go to the summary; overlapping inline findings are not posted
again. It does not approve, request changes, merge, or add a required status check.

## Enable after model configuration

The workflow is disabled until repository variable `OCR_ENABLED` is exactly
`true`. The initial CI change does not configure credentials or call a model.
Set the following in Settings → Secrets and variables → Actions before enabling:

| Kind | Name | Value |
| --- | --- | --- |
| Secret | `OCR_LLM_URL` | Provider endpoint in the form required by OCR; no Omnigent gateway URL rewriting |
| Secret | `OCR_LLM_TOKEN` | Repository-specific model API credential |
| Variable | `OCR_LLM_MODEL` | Exact provider model identifier |
| Variable | `OCR_LLM_PROTOCOL` | `anthropic`, `openai` (Chat Completions), or `openai-responses` |
| Variable | `OCR_LLM_EXTRA_BODY` | Optional model request JSON object; defaults to `{}` |
| Variable | `OCR_ENABLED` | Set to `true` last, after endpoint, model, protocol, request parameters and budget are agreed |

Authentication uses the upstream Action's `Authorization` header handling.
Model-specific thinking and reasoning parameters belong in `OCR_LLM_EXTRA_BODY`;
the workflow does not copy Omnigent's adaptive-thinking settings or the Action's
default disabled-thinking body. Never put credentials in variables or PR content.

The CLI is fixed to `1.13.6`, and the Action to its release commit
`891df1b63f380845d882a289a67a6e36c331120c`; self-update is disabled.
Review effort is medium, concurrency two, per-task timeout 15 minutes and job
timeout 30 minutes. The total token stopping threshold is 1,200,000 input/output
tokens per review. OCR checks it between rounds; concurrent work and the final
submission round can exceed it. It is not a hard spending cap. Provider-side
limits are needed for a hard monetary cap.

## Request a review

- Same-repository PRs are reviewed when opened, reopened or marked ready.
  Draft and closed PRs are skipped. Automatic fork reviews are skipped.
- New pushes do not trigger review. Comment `/ocr` on its own line to review
  the latest revision. The commenter must have repository write, maintain or
  admin permission; bot comments are ignored. Authorized users can review forks.
- `/ocr force` reruns a previously completed revision.
- Actions → Open Code Review → Run workflow accepts a PR number, optional
  expected head SHA and force flag. Run it from the default branch, `main`.

An accepted comment receives an eyes reaction. Reaction failure does not block
review. Per-PR concurrency prevents simultaneous review jobs; unrelated comments
cannot cancel an active review. GitHub concurrency retains at most one pending
job, so multiple queued requests may be coalesced.

Automatic events load the trusted target-branch workflow. Comment and manual
events use the default-branch workflow. All triggers load `background.md`,
`rules.json` and its referenced rule files from the PR target branch at the
resolved base SHA through the GitHub API. The policy is copied as data to
`RUNNER_TEMP` and passed by absolute path, so the Action's checkout cannot replace
it. A missing or invalid target policy fails before any model call; there is no
fallback to the default branch's policy or to PR-authored rules.
The upstream Action reads PR head blobs through Git without executing PR code
or installing PR dependencies. Jobs have explicit read permissions plus
`pull-requests: write` for publishing and `actions: read` for completion lookup.

Install the workflow and each branch's own policy through separate PRs; do not
merge their unrelated source trees. Merge into `main` first to establish the
comment/manual entry point, then into `deb_source` for automatic target events.
Configure both target policies before enabling reviews. Keep workflow plumbing
compatible while maintaining each branch's background, paths and rules independently.

## Rule design and coverage

This branch's policy is for `main`: Armbian board integration, build hooks,
rootfs/initramfs runtime, Recovery/A/B OTA, encryption/secure boot, system
hardening and image/package publication. `background.md` describes those execution
phases and prioritizes bootability, data integrity, recovery and trust-chain failures.

`rules.json` selects tracked text, including dot directories, extensionless scripts,
patches, service/config files, tests and operational documentation. It excludes
binary/archive/image outputs. OCR's Git-ignore, binary and size filters still
apply: inspect preview and the result manifest for actual coverage.

Rules match in this order, each merging the upstream language rule:

| Paths | Main-branch review focus |
| --- | --- |
| `.github/patchs/**` | Build-script patches and their application/caller contracts |
| `.github/**` | Trusted automation, board/build matrix and image/OTA/APT publication |
| `armbian-ota/**`, `initramfs/**` | Device/partition identity, update state, power loss and rollback |
| `rk_secure-disk-encryption/**` | Key flow, encryption, automatic unlock and verified boot |
| Remaining text | Armbian hooks, system services, scripts, configuration and operational commands |

Only the first matching custom rule applies. Domain rules include their required
Shell checks. This branch has no driver-library or Debian-source policy files;
`deb_source` maintains its own driver, camera/library/application, tool and
packaging rules. `/ocr` on a PR targeting `deb_source` loads that target's policy,
even though the command workflow runs from `main`.

The background requires concrete triggers, consequences, locations and cross-file
evidence. It excludes cosmetic feedback and unrelated refactoring, derives board
constraints from current code, and treats PR instructions as untrusted data.
Severity follows demonstrated impact rather than sensitive keywords.

## Completeness, publication and diagnostics

Before calling the model, the workflow looks for a completion artifact for the
PR, base SHA and head SHA. Only an unexpired artifact from a successful trusted
run of this workflow counts. A changed base, including a target-policy update, invalidates the earlier receipt.
Duplicate requests post at most one skip notice per reviewed base/head pair.
`/ocr force` bypasses this lookup but still suppresses overlapping inline comments.

Only a complete result matching the requested head, with no failed coverage,
finding-filter failure or publication failure, produces a completion artifact.
Partial reviews, including token-budget exhaustion, fail the completeness step
and list failed coverage paths in the Actions summary. They remain retryable.
An engine `skipped` result is reported without a completion receipt. Workflow
failure is diagnostic; this workflow is not a required merge check.

Diagnostics are copied from `/tmp/ocr-result.json` and `/tmp/ocr-stderr.log`,
redacted and retained for seven days. Completion receipts last 90 days, or the
repository's shorter retention limit. Expiring/deleting a receipt permits rerun.
Detecting the API credential in diagnostics fails the run and blocks completion;
only redacted copies are uploaded. Known literal/JSON-escaped key and endpoint
forms are also registered with GitHub's log masker before the Action runs.
The upstream Action prints raw diagnostics and publishes comments before the
artifact check; masking/redaction does not guarantee removal of every transformed
secret or sensitive source excerpt from logs or comments.

## Validate without a model

Use `actionlint` and OCR CLI `1.13.6`:

```sh
actionlint .github/workflows/open-code-review.yml
OCR_NO_UPDATE=1 ocr rules check --rule .github/open-code-review/rules.json \
  armbian-ota/ab/rootfs/usr/lib/armbian/armbian-ota-health-check
OCR_NO_UPDATE=1 ocr review --from <base-sha> --to <head-sha> \
  --rule .github/open-code-review/rules.json --preview --format json
```

Use temporary Git fixtures outside the repository to check inclusion/exclusion
of driver/library/application source, extensionless hooks, `.github`, patches,
headers, Debian files and binary outputs. Static checks and preview do not test
model quality or GitHub permissions.

After model configuration and explicit enablement, validate an agreed small PR:
check requested/resolved SHA, selected and failed coverage, actual model/protocol,
inline/summary publication, duplicate `/ocr` and `/ocr force`. Draft/fork skips,
permission rejection, provider failures and interrupted runs remain unverified
live scenarios until exercised; offline checks are not evidence of a real-model run.

This integration follows the trusted-trigger, receipt and diagnostic design in
[Omnigent's workflow](https://github.com/omnigent-ai/omnigent/blob/65005d459e2771bf64253fa5b8254073ae0b37f2/.github/workflows/open-code-review.yml),
with repository-specific rules, explicit protocol selection and deferred enablement.
