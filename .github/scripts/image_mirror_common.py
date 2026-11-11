"""Shared, side-effect-free helpers for the image mirror CI scripts."""

import json
import subprocess


class ImageMirrorError(Exception):
    pass


def command(program, args, input=None):
    try:
        result = subprocess.run(
            [program, *args], input=input, capture_output=True, text=True,
            # --contimeout covers connection establishment, not a stalled read.
            timeout=120,
        )
    except subprocess.TimeoutExpired as exc:
        raise ImageMirrorError(f"{program} {' '.join(args)} exceeded 120 seconds") from exc
    if result.returncode:
        raise ImageMirrorError(
            f"{program} {' '.join(args)}: {result.stderr.strip() or 'command failed'}"
        )
    return result.stdout


def decode(raw, description):
    try:
        return json.loads(raw)
    except json.JSONDecodeError as exc:
        raise ImageMirrorError(f"{description} is not valid JSON: {exc}") from exc


def optional_tag(slots, slot):
    tag = slots.get(slot)
    if tag is not None and (not isinstance(tag, str) or not tag or "/" in tag):
        raise ImageMirrorError(f"slots.json {slot} must be a safe tag string or null")
    return tag


def history_tags(slots, legacy=True):
    if "history" in slots:
        history = slots["history"]
        if not isinstance(history, list):
            raise ImageMirrorError("slots.json history must be an array")
    elif legacy:
        # Only a missing history key may use the legacy scalar pointer. Never
        # turn malformed current data into an empty reference set for GC.
        history = [slots["previous"]] if slots.get("previous") else []
    else:
        raise ImageMirrorError("slots.json history must be an array")
    if any(not isinstance(tag, str) or not tag or "/" in tag for tag in history):
        raise ImageMirrorError("slots.json history must contain only safe, non-empty tags")
    return history


def parse_slots(raw, legacy=True):
    slots = decode(raw, "slots.json") if isinstance(raw, str) else raw
    if not isinstance(slots, dict):
        raise ImageMirrorError(
            f"slots.json must be a JSON object, got {type(slots).__name__}"
        )
    return {
        "stable": optional_tag(slots, "stable"),
        "pre-release": optional_tag(slots, "pre-release"),
        "history": history_tags(slots, legacy=legacy),
    }


def references(slots):
    return set(filter(None, [slots["stable"], slots["pre-release"], *slots["history"]]))
