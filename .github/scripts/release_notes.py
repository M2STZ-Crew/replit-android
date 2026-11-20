"""The notes a release shows in "New update" and in Firebase (v1.12.58).

20 Nov 2026: "in updating feature, can you please remove the 'merge pull
request...'. we want to see only here is the version and what are the new
things. and type it in a professional way."

    python3 release_notes.py <pull request body> > release-notes.txt

The notes are the "What's new:" list of the pull request the release merged:

    What's new
    - Fires are now named with their barangay ...
    - ...

never GitHub's merge message ("Merge pull request #36 from ..."). A pull
request without such a list gives "Improvements and fixes." The version is
the release's title and the update sheet's heading, so the notes carry none.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

_HEADING = re.compile(r"^\s*(?:#+\s*)?(?:\*\*)?what'?s new:?(?:\*\*)?\s*$", re.IGNORECASE)
_ITEM = re.compile(r"^\s*[-*•]\s+")


def whats_new(body: str) -> list[str]:
    """The items under "What's new:", each on one line."""
    items: list[str] = []
    inside = False
    for line in body.replace("\r\n", "\n").split("\n"):
        if not inside:
            inside = bool(_HEADING.match(line))
            continue
        if _ITEM.match(line):
            items.append(_ITEM.sub("", line).strip())
        elif line.strip() and items and line.startswith((" ", "\t")):
            items[-1] += " " + line.strip()  # an item carried onto a second line
        elif line.strip() == "" and not items:
            continue
        else:
            break
    return [i for i in items if i]


def notes(body: str) -> str:
    items = whats_new(body) or ["Improvements and fixes."]
    return "What's new\n" + "\n".join(f"- {i}" for i in items) + "\n"


if __name__ == "__main__":
    path = Path(sys.argv[1]) if len(sys.argv) > 1 else None
    body = path.read_text(encoding="utf-8") if path and path.exists() else ""
    sys.stdout.write(notes(body))
