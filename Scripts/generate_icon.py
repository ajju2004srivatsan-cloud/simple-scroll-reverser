#!/usr/bin/env python3
"""Generate original macOS app icons for Simple Scroll Reverser."""

from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "SimpleScrollReverser" / "Assets.xcassets" / "AppIcon.appiconset"


def squircle_mask(size: int) -> Image.Image:
    """Big Sur-style superellipse mask."""
    img = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(img)
    n = 5.0
    steps = max(360, size * 2)
    pts = []
    for i in range(steps):
        t = (2 * math.pi * i) / steps
        ct, st = math.cos(t), math.sin(t)
        x = math.copysign(abs(ct) ** (2 / n), ct)
        y = math.copysign(abs(st) ** (2 / n), st)
        pts.append(((x + 1) * 0.5 * (size - 1), (y + 1) * 0.5 * (size - 1)))
    draw.polygon(pts, fill=255)
    return img.filter(ImageFilter.GaussianBlur(radius=max(size / 512, 0.4)))


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def paint_background(size: int) -> Image.Image:
    img = Image.new("RGB", (size, size))
    px = img.load()
    top = (18, 58, 92)
    bottom = (32, 158, 140)
    for y in range(size):
        color = lerp(top, bottom, y / max(size - 1, 1))
        for x in range(size):
            px[x, y] = color
    overlay = Image.new("RGB", (size, size))
    opx = overlay.load()
    highlight = (120, 210, 200)
    cx, cy = size * 0.32, size * 0.28
    radius = size * 0.85
    for y in range(size):
        for x in range(size):
            d = math.hypot(x - cx, y - cy) / radius
            t = max(0.0, 1.0 - d)
            opx[x, y] = lerp((0, 0, 0), highlight, t * 0.35)
    return Image.blend(img, overlay, 0.45)


def draw_arrows(draw: ImageDraw.ImageDraw, size: int) -> None:
    s = size
    stroke = max(int(s * 0.07), 2)
    # Two opposing chevrons suggesting reversed scrolling.
    def chevron(cx, top, bottom, pointing_up, color):
        half = s * 0.16
        if pointing_up:
            pts = [
                (cx, top),
                (cx - half, bottom),
                (cx - half + stroke * 0.9, bottom),
                (cx, top + stroke * 1.15),
                (cx + half - stroke * 0.9, bottom),
                (cx + half, bottom),
            ]
        else:
            pts = [
                (cx, bottom),
                (cx - half, top),
                (cx - half + stroke * 0.9, top),
                (cx, bottom - stroke * 1.15),
                (cx + half - stroke * 0.9, top),
                (cx + half, top),
            ]
        draw.polygon(pts, fill=color)

    color = (248, 252, 250)
    chevron(s * 0.38, s * 0.18, s * 0.50, True, color)
    chevron(s * 0.62, s * 0.50, s * 0.82, False, color)


def make_icon(size: int) -> Image.Image:
    rgb = paint_background(size)
    draw = ImageDraw.Draw(rgb)
    draw_arrows(draw, size)
    rgba = rgb.convert("RGBA")
    mask = squircle_mask(size)
    rgba.putalpha(mask)
    return rgba


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    sizes = {
        "icon_16.png": 16,
        "icon_32.png": 32,
        "icon_64.png": 64,
        "icon_128.png": 128,
        "icon_256.png": 256,
        "icon_512.png": 512,
        "icon_1024.png": 1024,
    }
    master = make_icon(1024)
    for name, size in sizes.items():
        image = master if size == 1024 else master.resize((size, size), Image.Resampling.LANCZOS)
        image.save(OUT / name, "PNG")
    print(f"Wrote {len(sizes)} icons to {OUT}")


if __name__ == "__main__":
    main()
