#!/usr/bin/env python3
"""Generate the two iPhone shortcuts "Moonlight open" and "Moonlight close" as signed files.

Each shortcut has two actions:
  1. Format Date: the current date as ISO 8601 with time.
  2. Get Contents of URL: POST {participant, platform, kind, occurred_at, source} as JSON to
     Supabase's test_events table.

The kind ("open"/"close") is fixed per shortcut, so the automations only need to run the right
shortcut, with no input passing.

Usage (macOS, signed in to iCloud):
  python3 ios-shortcuts/build_shortcuts.py --participant Sam \
      --url https://YOUR-PROJECT.supabase.co --key sb_publishable_...

Output: ios-shortcuts/out/<participant>/Moonlight open.shortcut and Moonlight close.shortcut,
signed with `shortcuts sign --mode anyone` so they can be AirDropped or sent to an iPhone.
"""

from __future__ import annotations

import argparse
import plistlib
import subprocess
import sys
import uuid
from pathlib import Path

OBJ = "￼"  # placeholder character Shortcuts uses where a variable sits inside text


def text(s: str) -> dict:
    return {"Value": {"string": s, "attachmentsByRange": {}}, "WFSerializationType": "WFTextTokenString"}


def text_with_output(output_uuid: str, output_name: str) -> dict:
    return {
        "Value": {
            "string": OBJ,
            "attachmentsByRange": {
                "{0, 1}": {"OutputUUID": output_uuid, "Type": "ActionOutput", "OutputName": output_name}
            },
        },
        "WFSerializationType": "WFTextTokenString",
    }


def dictionary(items: list[tuple[str, dict]]) -> dict:
    return {
        "Value": {
            "WFDictionaryFieldValueItems": [
                {"WFItemType": 0, "WFKey": text(k), "WFValue": v} for k, v in items
            ]
        },
        "WFSerializationType": "WFDictionaryFieldValue",
    }


def build(participant: str, kind: str, url: str, key: str) -> dict:
    date_uuid = str(uuid.uuid4()).upper()
    actions = [
        {
            "WFWorkflowActionIdentifier": "is.workflow.actions.format.date",
            "WFWorkflowActionParameters": {
                "UUID": date_uuid,
                "WFDateFormatStyle": "ISO 8601",
                "WFISO8601IncludeTime": True,
                "WFDate": {
                    "Value": {"string": OBJ, "attachmentsByRange": {"{0, 1}": {"Type": "CurrentDate"}}},
                    "WFSerializationType": "WFTextTokenString",
                },
            },
        },
        {
            "WFWorkflowActionIdentifier": "is.workflow.actions.downloadurl",
            "WFWorkflowActionParameters": {
                "UUID": str(uuid.uuid4()).upper(),
                "WFURL": url.rstrip("/") + "/rest/v1/test_events",
                "WFHTTPMethod": "POST",
                "ShowHeaders": True,
                "WFHTTPHeaders": dictionary([
                    ("apikey", text(key)),
                    ("Content-Type", text("application/json")),
                    ("Prefer", text("return=minimal")),
                ]),
                "WFHTTPBodyType": "JSON",
                "WFJSONValues": dictionary([
                    ("participant", text(participant)),
                    ("platform", text("ios")),
                    ("kind", text(kind)),
                    ("occurred_at", text_with_output(date_uuid, "Formatted Date")),
                    ("source", text("shortcut")),
                ]),
            },
        },
    ]
    return {
        "WFWorkflowActions": actions,
        "WFWorkflowClientVersion": "2605.0.5",
        "WFWorkflowMinimumClientVersion": 900,
        "WFWorkflowMinimumClientVersionString": "900",
        "WFWorkflowIcon": {"WFWorkflowIconStartColor": 1440408063, "WFWorkflowIconGlyphNumber": 59511},
        "WFWorkflowImportQuestions": [],
        "WFWorkflowInputContentItemClasses": [],
        "WFWorkflowOutputContentItemClasses": [],
        "WFWorkflowTypes": [],
        "WFWorkflowHasOutputFallback": False,
        "WFWorkflowHasShortcutInputVariables": False,
        "WFQuickActionSurfaces": [],
    }


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--participant", required=True)
    p.add_argument("--url", required=True, help="Supabase project URL, e.g. https://abc.supabase.co")
    p.add_argument("--key", required=True, help="public (anon/publishable) key, never the secret key")
    p.add_argument("--no-sign", action="store_true", help="write unsigned files only")
    a = p.parse_args()
    if a.key.startswith("sb_secret") or "service_role" in a.key:
        sys.exit("That looks like the secret key. Use the public (publishable/anon) key.")

    out = Path(__file__).with_name("out") / a.participant
    out.mkdir(parents=True, exist_ok=True)
    for kind in ("open", "close"):
        unsigned = out / f"Moonlight {kind}.unsigned.shortcut"
        signed = out / f"Moonlight {kind}.shortcut"
        with open(unsigned, "wb") as f:
            plistlib.dump(build(a.participant, kind, a.url, a.key), f, fmt=plistlib.FMT_BINARY)
        if a.no_sign:
            print(unsigned)
            continue
        subprocess.run(
            ["shortcuts", "sign", "--mode", "anyone", "--input", str(unsigned), "--output", str(signed)],
            check=True,
        )
        unsigned.unlink()
        print(signed)


if __name__ == "__main__":
    main()
