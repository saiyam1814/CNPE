#!/usr/bin/env python3
"""Static checks for the Killercoda course: index.json validity, referenced files,
executable bits, marker hygiene, and structure.json coverage."""

import json
import os
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
CNPE = ROOT / "cnpe"
errors = []
warnings = []

VALID_BACKENDS = {
    "kubernetes-kubeadm-1node", "kubernetes-kubeadm-1node-4GB",
    "kubernetes-kubeadm-2nodes", "ubuntu", "ubuntu-4GB",
}

structure = json.loads((CNPE / "structure.json").read_text())
listed = [item["path"] for item in structure["items"]]

dirs = sorted(d.name for d in CNPE.iterdir() if d.is_dir())
if listed != dirs:
    missing = set(dirs) - set(listed)
    extra = set(listed) - set(dirs)
    if missing:
        errors.append(f"structure.json missing dirs: {missing}")
    if extra:
        errors.append(f"structure.json lists nonexistent dirs: {extra}")

for d in dirs:
    base = CNPE / d
    idx_path = base / "index.json"
    if not idx_path.exists():
        errors.append(f"{d}: no index.json")
        continue
    try:
        idx = json.loads(idx_path.read_text())
    except json.JSONDecodeError as e:
        errors.append(f"{d}: index.json invalid JSON: {e}")
        continue

    backend = idx.get("backend", {}).get("imageid")
    if backend not in VALID_BACKENDS:
        errors.append(f"{d}: bad backend imageid {backend!r}")

    details = idx.get("details", {})
    refs = []
    intro = details.get("intro", {})
    for k in ("text", "background", "foreground"):
        if k in intro:
            refs.append(intro[k])
    for step in details.get("steps", []):
        for k in ("text", "verify", "background", "foreground"):
            if k in step:
                refs.append(step[k])
    fin = details.get("finish", {})
    if "text" in fin:
        refs.append(fin["text"])

    for r in refs:
        p = base / r
        if not p.exists():
            errors.append(f"{d}: index.json references missing file {r}")
        elif r.endswith(".sh") and not os.access(p, os.X_OK):
            warnings.append(f"{d}: {r} not executable (killercoda runs via bash, ok, but chmod +x anyway)")

    # every dir file should be referenced or be a known extra
    known_extra = {"index.json"}
    files = {f.name for f in base.iterdir() if f.is_file()}
    unreferenced = files - set(refs) - known_extra
    if unreferenced:
        warnings.append(f"{d}: unreferenced files: {sorted(unreferenced)}")

    # markdown hygiene: exec/copy markers on fenced blocks
    for md in base.glob("*.md"):
        text = md.read_text()
        # heredoc blocks inside ```bash ...```{{exec}} that contain unbalanced EOF
        for m in re.finditer(r"```(\w*)\n(.*?)```(\{\{\w+.*?\}\})?", text, re.S):
            body = m.group(2)
            if "<<'EOF'" in body or "<<EOF" in body:
                if body.count("EOF") < 2:
                    errors.append(f"{d}/{md.name}: heredoc without terminator in a code block")
    # setup.sh must end with the done marker
    setup = base / "setup.sh"
    if setup.exists() and ".cnpe-setup-done" not in setup.read_text():
        errors.append(f"{d}: setup.sh missing the setup-done marker")

    # verify scripts must not be empty and must exit 0/1 style
    for v in base.glob("verify*.sh"):
        body = v.read_text()
        if "exit 0" not in body:
            warnings.append(f"{d}/{v.name}: no explicit exit 0")

print(f"checked {len(dirs)} scenarios")
for w in warnings:
    print("WARN ", w)
for e in errors:
    print("ERROR", e)
sys.exit(1 if errors else 0)
