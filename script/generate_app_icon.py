#!/usr/bin/env python3
from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
SOURCE_ICO = ROOT / "Resources" / "IconSource" / "WinMTR.ico"
OUTPUT_DIR = ROOT / "Resources"
ICONSET_DIR = OUTPUT_DIR / "AppIcon.iconset"
MASTER_PNG = OUTPUT_DIR / "AppIcon.png"


ICONSET_SIZES = {
    "icon_16x16.png": 16,
    "icon_16x16@2x.png": 32,
    "icon_32x32.png": 32,
    "icon_32x32@2x.png": 64,
    "icon_128x128.png": 128,
    "icon_128x128@2x.png": 256,
    "icon_256x256.png": 256,
    "icon_256x256@2x.png": 512,
    "icon_512x512.png": 512,
    "icon_512x512@2x.png": 1024,
}


def load_source_icon() -> Image.Image:
    image = Image.open(SOURCE_ICO)
    frames: list[Image.Image] = []

    try:
        index = 0
        while True:
            image.seek(index)
            frames.append(image.copy().convert("RGBA"))
            index += 1
    except EOFError:
        pass

    return max(frames, key=lambda frame: frame.width * frame.height)


def rounded_mask(size: int, radius: int) -> Image.Image:
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, size, size), radius=radius, fill=255)
    return mask


def draw_background(size: int) -> Image.Image:
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)

    for y in range(size):
        t = y / (size - 1)
        r = int(10 + 24 * t)
        g = int(118 + 70 * (1 - t))
        b = int(198 + 20 * (1 - t))
        draw.line((0, y, size, y), fill=(r, g, b, 255))

    grid = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    grid_draw = ImageDraw.Draw(grid)
    step = size // 8
    for i in range(1, 8):
        alpha = 28 if i % 2 else 40
        x = i * step
        y = i * step
        grid_draw.line((x, size * 0.12, x, size * 0.88), fill=(255, 255, 255, alpha), width=max(1, size // 180))
        grid_draw.line((size * 0.12, y, size * 0.88, y), fill=(255, 255, 255, alpha), width=max(1, size // 180))
    image.alpha_composite(grid)

    mask = rounded_mask(size, int(size * 0.22))
    image.putalpha(mask)

    shine = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    shine_draw = ImageDraw.Draw(shine)
    shine_draw.ellipse(
        (-size * 0.20, -size * 0.45, size * 1.20, size * 0.92),
        fill=(255, 255, 255, 38),
    )
    shine.putalpha(Image.composite(shine.getchannel("A"), Image.new("L", (size, size), 0), mask))
    image.alpha_composite(shine)

    shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.rounded_rectangle(
        (size * 0.05, size * 0.055, size * 0.95, size * 0.96),
        radius=int(size * 0.20),
        outline=(0, 0, 0, 76),
        width=max(2, size // 42),
    )
    image.alpha_composite(shadow)

    return image


def draw_route_overlay(image: Image.Image) -> None:
    size = image.width
    draw = ImageDraw.Draw(image)
    points = [
        (size * 0.19, size * 0.66),
        (size * 0.34, size * 0.51),
        (size * 0.50, size * 0.58),
        (size * 0.67, size * 0.38),
        (size * 0.82, size * 0.46),
    ]
    points = [(int(x), int(y)) for x, y in points]

    for offset, alpha, width in [(10, 70, size // 30), (0, 255, size // 48)]:
        shifted = [(x, y + offset) for x, y in points]
        draw.line(shifted, fill=(255, 70, 80, alpha), width=width, joint="curve")

    radius = max(9, size // 42)
    for index, (x, y) in enumerate(points):
        fill = (255, 238, 115, 255) if index in (0, len(points) - 1) else (255, 255, 255, 245)
        draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=fill, outline=(75, 22, 28, 170), width=max(2, size // 128))


def paste_source_glyph(image: Image.Image, source: Image.Image) -> None:
    size = image.width
    glyph_size = int(size * 0.40)
    glyph = source.resize((glyph_size, glyph_size), Image.Resampling.NEAREST)

    backing = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(backing)
    cx = size // 2
    cy = int(size * 0.66)
    pad = int(size * 0.048)
    rect = (
        cx - glyph_size // 2 - pad,
        cy - glyph_size // 2 - pad,
        cx + glyph_size // 2 + pad,
        cy + glyph_size // 2 + pad,
    )
    draw.rounded_rectangle(rect, radius=int(size * 0.052), fill=(12, 21, 29, 212))
    draw.rounded_rectangle(rect, radius=int(size * 0.052), outline=(255, 255, 255, 62), width=max(2, size // 128))
    backing = backing.filter(ImageFilter.GaussianBlur(radius=0.2))
    image.alpha_composite(backing)
    image.alpha_composite(glyph, (cx - glyph_size // 2, cy - glyph_size // 2))


def draw_latency_arc(image: Image.Image) -> None:
    size = image.width
    draw = ImageDraw.Draw(image)
    center = (size // 2, int(size * 0.36))
    radius = int(size * 0.20)
    line_width = max(8, size // 38)

    for alpha, width_add in [(70, size // 34), (255, 0)]:
        draw.arc(
            (
                center[0] - radius,
                center[1] - radius,
                center[0] + radius,
                center[1] + radius,
            ),
            start=205,
            end=335,
            fill=(220, 246, 255, alpha),
            width=line_width + width_add,
        )

    needle_angle = math.radians(304)
    end = (
        int(center[0] + math.cos(needle_angle) * radius * 0.84),
        int(center[1] + math.sin(needle_angle) * radius * 0.84),
    )
    draw.line((center, end), fill=(255, 77, 88, 255), width=max(6, size // 52))
    hub = max(11, size // 36)
    draw.ellipse(
        (center[0] - hub, center[1] - hub, center[0] + hub, center[1] + hub),
        fill=(245, 250, 255, 255),
        outline=(38, 92, 126, 180),
        width=max(2, size // 170),
    )


def make_master() -> Image.Image:
    source = load_source_icon()
    image = draw_background(1024)
    draw_latency_arc(image)
    draw_route_overlay(image)
    paste_source_glyph(image, source)
    return image


def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    ICONSET_DIR.mkdir(parents=True, exist_ok=True)

    master = make_master()
    master.save(MASTER_PNG)

    for filename, size in ICONSET_SIZES.items():
        resized = master.resize((size, size), Image.Resampling.LANCZOS)
        resized.save(ICONSET_DIR / filename)

    print(MASTER_PNG)
    print(ICONSET_DIR)


if __name__ == "__main__":
    main()
