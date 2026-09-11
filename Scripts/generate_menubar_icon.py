#!/usr/bin/env python3
"""Black-on-transparent template PNGs for the menu bar status item."""

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "SimpleScrollReverser" / "Assets.xcassets" / "MenuBarIcon.imageset"


def draw_arrows(size: int) -> Image.Image:
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    stroke = max(int(round(size * 0.14)), 2)
    color = (0, 0, 0, 255)
    inset = size * 0.18
    mid = size / 2
    # Up chevron (left)
    left_x = size * 0.32
    draw.line(
        [(left_x - size * 0.16, mid - inset * 0.1), (left_x, inset), (left_x + size * 0.16, mid - inset * 0.1)],
        fill=color,
        width=stroke,
        joint="curve",
    )
    # Down chevron (right)
    right_x = size * 0.68
    draw.line(
        [(right_x - size * 0.16, mid + inset * 0.1), (right_x, size - inset), (right_x + size * 0.16, mid + inset * 0.1)],
        fill=color,
        width=stroke,
        joint="curve",
    )
    return img


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    draw_arrows(18).save(OUT / "MenuBarIcon.png", "PNG")
    draw_arrows(36).save(OUT / "MenuBarIcon@2x.png", "PNG")
    print(f"Wrote menu bar icons to {OUT}")


if __name__ == "__main__":
    main()
