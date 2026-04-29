#!/usr/bin/env python3
from pathlib import Path
from PIL import Image


ASSETS = Path(__file__).resolve().parents[1] / "fitnesscoach" / "Assets.xcassets"
EXPECTED_SIZE = (682, 1024)

MASK_ASSETS = [
    "MMask_front_adductor",
    "MMask_front_quad",
    "MMask_front_calf",
    "MMask_front_forearm",
    "MMask_front_trap",
    "MMask_front_quad_vl",
    "MMask_front_shoulders",
    "MMask_front_biceps",
    "MMask_front_chest",
    "MMask_front_abs_oblique",
    "MMask_front_abs_rectus",
    "MMask_back_upper",
    "MMask_back_lower",
    "MMask_back_ham",
    "MMask_back_calf",
    "MMask_back_forearm",
    "MMask_back_glute",
    "MMask_back_shoulders",
    "MMask_back_triceps",
    "MMask_back_lats",
]


def main() -> int:
    failures: list[str] = []
    for asset in MASK_ASSETS:
        img_path = ASSETS / f"{asset}.imageset" / f"{asset}.png"
        if not img_path.exists():
            failures.append(f"{asset}: missing image file")
            continue

        img = Image.open(img_path)
        if img.mode != "RGBA":
            failures.append(f"{asset}: mode={img.mode}, expected RGBA")
        if img.size != EXPECTED_SIZE:
            failures.append(f"{asset}: size={img.size}, expected={EXPECTED_SIZE}")

        alpha = img.getchannel("A")
        amin, amax = alpha.getextrema()
        if amin != 0:
            failures.append(f"{asset}: no fully transparent pixel found")
        if amax == 0:
            failures.append(f"{asset}: alpha is fully transparent")

    if failures:
        print("Mask validation failed:")
        for f in failures:
            print(f"- {f}")
        return 1

    print(f"Mask validation passed: {len(MASK_ASSETS)} assets checked.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
