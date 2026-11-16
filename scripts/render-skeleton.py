#!/usr/bin/env python3
"""Render backstage/skeleton the way Backstage's fetch:template does, for CI.

Substitutes ${{ values.<key> }} in file contents and paths, and copies files
matching copyWithoutTemplating unchanged. Fails if any placeholder survives,
so a typo in the skeleton cannot reach a team's new repository.

Usage: render-skeleton.py <out-dir> [key=value ...]
"""
import fnmatch
import os
import re
import sys

SKELETON = os.path.join(os.path.dirname(__file__), "..", "backstage", "skeleton")
NO_TEMPLATING = [".github/workflows/*"]
DEFAULTS = {
    "name": "orders-api",
    "description": "Order intake API",
    "owner": "group:default/payments",
    "team": "payments",
    "repoOwner": "example-org",
    "repoName": "orders-api",
}
PLACEHOLDER = re.compile(r"\$\{\{\s*values\.(\w+)\s*\}\}")


def render(text: str, values: dict, where: str) -> str:
    def sub(m):
        key = m.group(1)
        if key not in values:
            sys.exit(f"{where}: unknown value '{key}'")
        return values[key]

    return PLACEHOLDER.sub(sub, text)


def main() -> None:
    out = sys.argv[1]
    values = dict(DEFAULTS)
    values.update(kv.split("=", 1) for kv in sys.argv[2:])

    for root, _, files in os.walk(SKELETON):
        for name in files:
            src = os.path.join(root, name)
            rel = os.path.relpath(src, SKELETON)
            verbatim = any(fnmatch.fnmatch(rel, p) for p in NO_TEMPLATING)
            dst_rel = rel if verbatim else render(rel, values, rel)
            with open(src, encoding="utf-8") as f:
                text = f.read()
            if not verbatim:
                text = render(text, values, rel)
                if "${{" in text and "values." in text:
                    sys.exit(f"{rel}: unrendered placeholder")
            dst = os.path.join(out, dst_rel)
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            with open(dst, "w", encoding="utf-8") as f:
                f.write(text)
            print(dst_rel)


if __name__ == "__main__":
    main()
