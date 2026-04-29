#!/usr/bin/env python3
from pathlib import Path
import sys
from PIL import Image


EXPECTED = (682, 1024)


def check_folder(root: Path) -> int:
    errors: list[str] = []
    for side in ("前", "后"):
        side_dir = root / side
        if not side_dir.exists():
            errors.append(f"missing folder: {side_dir}")
            continue
        pngs = sorted(side_dir.glob("*.png"))
        if not pngs:
            errors.append(f"no png files: {side_dir}")
            continue
        for p in pngs:
            img = Image.open(p)
            if img.size != EXPECTED:
                errors.append(f"{p.name}: size {img.size}, expected {EXPECTED}")
            if img.mode != "RGBA":
                errors.append(f"{p.name}: mode {img.mode}, expected RGBA")
            a_min, a_max = img.getchannel("A").getextrema()
            if a_min != 0:
                errors.append(f"{p.name}: no transparent area")
            if a_max == 0:
                errors.append(f"{p.name}: fully transparent")

    if errors:
        print("Source mask folder INVALID:")
        for e in errors:
            print(f"- {e}")
        return 1
    print(f"Source mask folder valid: {root}")
    return 0


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python3 scripts/validate_mask_source_folder.py <source_folder>")
        raise SystemExit(2)
    raise SystemExit(check_folder(Path(sys.argv[1]).expanduser().resolve()))
