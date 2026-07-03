#!/usr/bin/env python3
from __future__ import annotations

import math
import shutil
import subprocess
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
OUTPUT_DIR = ROOT / "Resources"
ICON_DOCUMENT = OUTPUT_DIR / "MacMTR.icon"
ICON_DOCUMENT_ASSET = ICON_DOCUMENT / "Assets" / "AppIconForeground.png"
ICONSET_DIR = OUTPUT_DIR / "AppIcon.iconset"
MASTER_PNG = OUTPUT_DIR / "AppIcon.png"
FOREGROUND_PNG = OUTPUT_DIR / "AppIconForeground.png"
APP_ICON_ICNS = OUTPUT_DIR / "AppIcon.icns"
ICTOOL = Path("/Applications/Icon Composer.app/Contents/Executables/ictool")


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


def draw_foreground(size: int = 1024) -> Image.Image:
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)

    panel = (
        int(size * 0.205),
        int(size * 0.345),
        int(size * 0.795),
        int(size * 0.765),
    )
    shadow_draw.rounded_rectangle(
        (panel[0] + size * 0.018, panel[1] + size * 0.035, panel[2] + size * 0.018, panel[3] + size * 0.035),
        radius=int(size * 0.075),
        fill=(2, 20, 42, 112),
    )
    image.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(size * 0.025)))

    panel_img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    panel_draw = ImageDraw.Draw(panel_img)
    panel_draw.rounded_rectangle(panel, radius=int(size * 0.074), fill=(11, 32, 52, 218))
    panel_draw.rounded_rectangle(
        (panel[0] + 4, panel[1] + 4, panel[2] - 4, panel[3] - 4),
        radius=int(size * 0.066),
        outline=(255, 255, 255, 56),
        width=max(3, size // 180),
    )
    image.alpha_composite(panel_img)

    draw = ImageDraw.Draw(image)
    route_points = [
        (int(size * 0.245), int(size * 0.675)),
        (int(size * 0.405), int(size * 0.535)),
        (int(size * 0.565), int(size * 0.595)),
        (int(size * 0.735), int(size * 0.455)),
    ]

    draw.line(route_points, fill=(0, 0, 0, 80), width=max(18, size // 38), joint="curve")
    draw.line(route_points, fill=(255, 86, 102, 255), width=max(14, size // 48), joint="curve")
    draw.line(route_points, fill=(255, 180, 112, 170), width=max(5, size // 128), joint="curve")

    for index, (x, y) in enumerate(route_points):
        radius = int(size * (0.047 if index in (0, len(route_points) - 1) else 0.039))
        draw.ellipse(
            (x - radius - 5, y - radius + 7, x + radius + 5, y + radius + 17),
            fill=(0, 0, 0, 74),
        )
        fill = (255, 226, 86, 255) if index in (0, len(route_points) - 1) else (236, 250, 255, 255)
        draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=fill)
        draw.ellipse(
            (x - radius, y - radius, x + radius, y + radius),
            outline=(79, 21, 36, 190),
            width=max(5, size // 82),
        )

    gauge_center = (int(size * 0.50), int(size * 0.365))
    gauge_radius = int(size * 0.205)
    arc_box = (
        gauge_center[0] - gauge_radius,
        gauge_center[1] - gauge_radius,
        gauge_center[0] + gauge_radius,
        gauge_center[1] + gauge_radius,
    )
    draw.arc(arc_box, start=205, end=335, fill=(8, 27, 50, 84), width=max(31, size // 22))
    draw.arc(arc_box, start=205, end=335, fill=(237, 250, 255, 242), width=max(23, size // 30))

    needle_angle = math.radians(306)
    needle_end = (
        int(gauge_center[0] + math.cos(needle_angle) * gauge_radius * 0.82),
        int(gauge_center[1] + math.sin(needle_angle) * gauge_radius * 0.82),
    )
    draw.line((gauge_center, needle_end), fill=(255, 72, 86, 255), width=max(10, size // 64))
    hub = int(size * 0.034)
    draw.ellipse(
        (gauge_center[0] - hub, gauge_center[1] - hub, gauge_center[0] + hub, gauge_center[1] + hub),
        fill=(247, 252, 255, 255),
        outline=(26, 82, 123, 208),
        width=max(3, size // 128),
    )

    return image


def export_icon_composer_png() -> None:
    if not ICON_DOCUMENT.exists():
        raise SystemExit(f"Missing Icon Composer document: {ICON_DOCUMENT}")
    if not ICTOOL.exists():
        raise SystemExit(f"Missing Icon Composer export tool: {ICTOOL}")

    subprocess.run(
        [
            str(ICTOOL),
            str(ICON_DOCUMENT),
            "--export-image",
            "--output-file",
            str(MASTER_PNG),
            "--platform",
            "macOS",
            "--rendition",
            "Default",
            "--width",
            "1024",
            "--height",
            "1024",
            "--scale",
            "1",
        ],
        cwd=ROOT,
        check=True,
    )


def write_iconset() -> None:
    if ICONSET_DIR.exists():
        shutil.rmtree(ICONSET_DIR)
    ICONSET_DIR.mkdir(parents=True, exist_ok=True)

    master = Image.open(MASTER_PNG).convert("RGBA")
    for filename, size in ICONSET_SIZES.items():
        master.resize((size, size), Image.Resampling.LANCZOS).save(ICONSET_DIR / filename)

    subprocess.run(
        ["iconutil", "-c", "icns", str(ICONSET_DIR), "-o", str(APP_ICON_ICNS)],
        cwd=ROOT,
        check=True,
    )


def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    foreground = draw_foreground()
    foreground.save(FOREGROUND_PNG)

    if ICON_DOCUMENT_ASSET.exists():
        shutil.copy2(FOREGROUND_PNG, ICON_DOCUMENT_ASSET)

    export_icon_composer_png()
    write_iconset()

    print(MASTER_PNG)
    print(FOREGROUND_PNG)
    print(ICON_DOCUMENT)
    print(APP_ICON_ICNS)


if __name__ == "__main__":
    main()
