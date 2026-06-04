#!/usr/bin/env python3
"""Generate StatusTodo app icon: dark bg, three todo rows with coloured status dots."""

from PIL import Image, ImageDraw
import os, math

# ── Palette ──────────────────────────────────────────────────────────────────
BG        = (28,  28,  28)        # #1C1C1C  app background
ROW_BG    = (38,  38,  38)        # slightly lighter row bg
DOTS      = [
    (0,   200, 117),   # green  – done
    (255, 140,   0),   # orange – in progress
    (74,  144, 217),   # blue   – waiting
]
LINE      = (80, 80, 80)          # text line colour

def make_icon(size: int) -> Image.Image:
    img  = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # ── Rounded-rect background ───────────────────────────────────────────────
    radius  = size * 0.22
    draw.rounded_rectangle([0, 0, size - 1, size - 1], radius=radius, fill=BG)

    # ── Three todo rows ───────────────────────────────────────────────────────
    padding   = size * 0.14
    row_h     = (size - 2 * padding) / 4.2
    dot_r     = row_h * 0.26
    line_h    = dot_r * 0.45
    gap       = size * 0.055          # gap between dot and line

    for i, dot_colour in enumerate(DOTS):
        cy = padding + row_h * (i + 0.6)
        cx = padding + dot_r

        # row pill background
        row_y1 = cy - row_h * 0.44
        row_y2 = cy + row_h * 0.44
        draw.rounded_rectangle(
            [padding * 0.5, row_y1, size - padding * 0.5, row_y2],
            radius=dot_r * 0.5,
            fill=ROW_BG,
        )

        # coloured status dot
        draw.ellipse(
            [cx - dot_r, cy - dot_r, cx + dot_r, cy + dot_r],
            fill=dot_colour,
        )

        # text stub line
        line_x1 = cx + dot_r + gap
        line_x2 = size - padding - gap
        line_y  = cy - line_h / 2
        draw.rounded_rectangle(
            [line_x1, line_y, line_x2, line_y + line_h],
            radius=line_h / 2,
            fill=LINE,
        )

    return img


def main():
    sizes = [16, 32, 64, 128, 256, 512, 1024]
    out_dir = os.path.join(
        os.path.dirname(__file__),
        "StatusTodo", "Assets.xcassets", "AppIcon.appiconset"
    )
    os.makedirs(out_dir, exist_ok=True)

    filenames = []
    for s in sizes:
        img  = make_icon(s)
        name = f"icon_{s}.png"
        img.save(os.path.join(out_dir, name), "PNG")
        filenames.append((s, name))
        print(f"  ✓ {s}×{s}")

    # ── Contents.json ─────────────────────────────────────────────────────────
    # macOS needs 16,32,64,128,256,512 at 1× and 2×
    entries = []
    pairs = [
        (16,  "1x", 16),  (16,  "2x", 32),
        (32,  "1x", 32),  (32,  "2x", 64),
        (128, "1x", 128), (128, "2x", 256),
        (256, "1x", 256), (256, "2x", 512),
        (512, "1x", 512), (512, "2x", 1024),
    ]
    for pt, scale, px in pairs:
        entries.append(
            f'    {{\n'
            f'      "filename": "icon_{px}.png",\n'
            f'      "idiom": "mac",\n'
            f'      "scale": "{scale}",\n'
            f'      "size": "{pt}x{pt}"\n'
            f'    }}'
        )

    contents = (
        '{\n'
        '  "images": [\n' +
        ',\n'.join(entries) +
        '\n  ],\n'
        '  "info": { "author": "xcode", "version": 1 }\n'
        '}\n'
    )

    with open(os.path.join(out_dir, "Contents.json"), "w") as f:
        f.write(contents)
    print("  ✓ Contents.json")
    print(f"\nIcon set written to:\n  {out_dir}")


if __name__ == "__main__":
    main()
