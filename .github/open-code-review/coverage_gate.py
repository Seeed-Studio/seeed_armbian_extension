"""Classify official OCR preview exclusions; never execute PR content."""
import argparse
import json
import pathlib
import subprocess


# Source code and executable build languages; data/configuration extensions
# (JSON, YAML, XML, binary assets, etc.) are intentionally absent.
SOURCE_SUFFIXES = {
    '.c', '.h', '.cc', '.hh', '.cpp', '.hpp', '.cxx', '.hxx', '.s', '.asm',
    '.go', '.rs', '.py', '.pyi', '.sh', '.bash', '.dash', '.zsh', '.fish',
    '.js', '.jsx', '.mjs', '.cjs', '.ts', '.tsx', '.java', '.kt', '.kts',
    '.cs', '.fs', '.fsx', '.swift', '.m', '.mm', '.rb', '.pl', '.pm', '.lua',
    '.php', '.r', '.jl', '.scala', '.sc', '.ex', '.exs', '.erl', '.hrl',
    '.hs', '.ml', '.mli', '.clj', '.cljs', '.dart', '.vue', '.svelte',
    '.sql', '.cmake', '.mk', '.bzl', '.gradle', '.groovy', '.v', '.sv',
    '.vhd', '.vhdl', '.dts', '.dtsi', '.patch', '.diff',
}
SOURCE_NAMES = {'Makefile', 'GNUmakefile', 'makefile', 'CMakeLists.txt',
                'Dockerfile', 'Containerfile', 'Kbuild', 'Kconfig', 'BUILD',
                'BUILD.bazel', 'WORKSPACE'}


def is_source(path, read_prefix=None):
    name = pathlib.PurePosixPath(path)
    if name.suffix.lower() in SOURCE_SUFFIXES or name.name in SOURCE_NAMES:
        return True
    # Do not mistake a data extension for source, even if its content starts #!.
    return not name.suffix and read_prefix is not None and read_prefix(path).startswith(b'#!')


def git_prefix(head, path):
    # Read a bounded prefix of the pinned blob; never execute the PR's file.
    process = subprocess.Popen(['git', 'show', f'{head}:{path}'], stdout=subprocess.PIPE,
                               stderr=subprocess.DEVNULL)
    try:
        prefix = process.stdout.read(256)
    finally:
        process.stdout.close()
        if process.poll() is None:
            process.terminate()
        returncode = process.wait()
    if returncode > 0:
        raise ValueError(f'Cannot inspect source type for {path!r}')
    return prefix


def evaluate(preview, read_prefix=None):
    if not isinstance(preview, dict) or not isinstance(preview.get('files'), list):
        raise ValueError('OCR preview must contain a files array')
    findings = []
    non_source = []
    for entry in preview['files']:
        if not isinstance(entry, dict) or not isinstance(entry.get('path'), str):
            raise ValueError('Invalid OCR preview file entry')
        if type(entry.get('will_review')) is not bool:
            raise ValueError('OCR preview is missing will_review')
        if entry.get('exclude_reason') != 'too_large':
            continue
        if entry['will_review']:
            raise ValueError('Contradictory OCR too_large entry')
        path = entry['path']
        if not is_source(path, read_prefix):
            non_source.append(path)
        else:
            findings.append({'severity': 'critical', 'category': 'review_coverage',
                             'path': path, 'reason': 'too_large',
                             'message': '源代码或代码 diff 因超过 OCR 输入限制未审查；阻塞合并。'})
    return {'status': 'failure' if findings else 'success',
            'findings': findings, 'oversized_non_source': non_source}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('preview', type=pathlib.Path)
    parser.add_argument('output', type=pathlib.Path)
    parser.add_argument('--head', required=True)
    args = parser.parse_args()
    head = subprocess.check_output(['git', 'rev-parse', '--verify', '--end-of-options',
                                    args.head + '^{commit}'], text=True).strip()
    result = evaluate(json.loads(args.preview.read_text()), lambda path: git_prefix(head, path))
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    # The workflow publishes the exact-head check before failing the job.


if __name__ == '__main__':
    main()
