#!/usr/bin/env python3
"""Renders Just Hashi's Mac, Apple TV and Vision Pro icons.

    python3 tools/icon/generate_platform_icons.py

Same picture as the iOS icon (`generate_appicon.py`, whose drawing code this
reuses): a legal one-move board, islands 2/3/1 joined by a double and a single
bridge on a dark sea. Each platform needs it in a different shape:

* **Mac** does not mask icons, so the rounded tile is part of the artwork: an
  824px tile on a 1024 canvas, corner radius 22.37% of the tile, transparent
  around it (Apple's grid). Written as `mac-*.png` into AppIcon.appiconset.
* **Apple TV** icons are 5:3 and layered; the system slides the layers against
  each other as focus moves. Back = sea and waves, middle = bridges, front =
  islands and numbers, so the islands float over the water. Never masked.
  `TVAppIcon.brandassets`, with the App Store size and Top Shelf images.
* **Vision Pro** icons are three layers cut into a circle, tilted apart as
  you look around. Same split. `VisionAppIcon.solidimagestack`.

The back layers are opaque (the base the system cuts from); the others are
transparent. Requires Pillow.
"""

import json
import math
import pathlib
import shutil
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import generate_appicon as base  # noqa: E402

ASSETS = pathlib.Path(__file__).resolve().parents[2] / "Hashi/Assets.xcassets"
INFO = {"author": "xcode", "version": 1}
ORDER = ["Front", "Middle", "Back"]


# --- the picture, split ---------------------------------------------------

def square_layer(which):
    """One layer of the 1024 icon, transparent except for its own content."""
    render = base.SIZE * base.SCALE
    if which == "Back":
        image = Image.new("RGB", (render, render))
        draw = ImageDraw.Draw(image)
        base.draw_sea(draw, render)
        base.draw_waves(draw, render)
    else:
        image = Image.new("RGBA", (render, render), (0, 0, 0, 0))
        draw = ImageDraw.Draw(image)
        if which == "Middle":
            base.draw_rails(draw, base.A, base.B, count=2)
            base.draw_rails(draw, base.B, base.C, count=1)
        else:
            for centre in (base.A, base.B, base.C):
                base.draw_island(draw, centre, base.R)
            font = base.digit_font(base.load_font(), draw)
            for text, centre in (("2", base.A), ("3", base.B), ("1", base.C)):
                base.draw_digit(draw, text, centre, font)
    return image.resize((base.SIZE, base.SIZE), Image.LANCZOS)


def wide_sea(width, height):
    """The sea for a wide canvas: the icon's gradient top to bottom, and its
    wave rows at the icon's pitch, scaled to the height and repeated across."""
    k = height / base.SIZE
    image = Image.new("RGB", (width, height))
    draw = ImageDraw.Draw(image)
    for y in range(height):
        t = y / (height - 1)
        draw.line([(0, y), (width, y)], fill=tuple(
            int(base.SEA_TOP[i] + (base.SEA_BOTTOM[i] - base.SEA_TOP[i]) * t) for i in range(3)))
    for row in range(base.WAVE_ROWS):
        y = (base.WAVE_Y0 + row * base.WAVE_PITCH_Y) * k
        t = y / (height - 1)
        tone = tuple(int(base.SEA_TOP[i] + (base.SEA_BOTTOM[i] - base.SEA_TOP[i]) * t) for i in range(3))
        ink = tuple(min(255, c + base.WAVE_LIFT) for c in tone)
        x = 30 * k + (base.WAVE_PITCH_X / 2 * k if row % 2 else 0)
        while x < width:
            span = base.WAVE_DASH * k
            points = [(x + step, y - 6 * k * math.sin(math.pi * step / span))
                      for step in range(0, max(2, int(span)), 1)]
            draw.line(points, fill=ink, width=max(1, int(3 * k)))
            x += base.WAVE_PITCH_X * k
    return image


def layer_on(width, height, which, art_height):
    """A layer for a width×height canvas; the square art is centred at
    `art_height` tall."""
    if which == "Back":
        return wide_sea(width, height)
    art = square_layer(which).resize((art_height, art_height), Image.LANCZOS)
    canvas = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    canvas.paste(art, ((width - art_height) // 2, (height - art_height) // 2), art)
    return canvas


# --- writers --------------------------------------------------------------

def write_json(path, obj):
    path.mkdir(parents=True, exist_ok=True)
    (path / "Contents.json").write_text(json.dumps(obj, indent=2) + "\n")


def write_stack(root, scales, width, height, art_height, idiom, solid=False):
    ext = "solidimagestacklayer" if solid else "imagestacklayer"
    write_json(root, {"info": INFO, "layers": [{"filename": f"{n}.{ext}"} for n in ORDER]})
    for name in ORDER:
        folder = root / f"{name}.{ext}"
        write_json(folder, {"info": INFO})
        images = []
        for scale in scales:
            art = layer_on(width * scale, height * scale, name, art_height * scale)
            filename = f"{name.lower()}.png" if solid else f"{name.lower()}@{scale}.png"
            (folder / "Content.imageset").mkdir(parents=True, exist_ok=True)
            art.save(folder / "Content.imageset" / filename)
            images.append({"filename": filename, "idiom": idiom,
                           "scale": "2x" if solid else f"{scale}x"})
        write_json(folder / "Content.imageset", {"images": images, "info": INFO})


def top_shelf(width, height):
    """Behind the app on the Apple TV Home screen: the sea, with the three
    islands sitting a little left of centre."""
    image = wide_sea(width, height).convert("RGBA")
    art_h = int(height * 0.86)
    for which in ("Middle", "Front"):
        art = square_layer(which).resize((art_h, art_h), Image.LANCZOS)
        image.alpha_composite(art, (int(width * 0.36 - art_h / 2), (height - art_h) // 2))
    return image.convert("RGB")


def tv():
    root = ASSETS / "TVAppIcon.brandassets"
    shutil.rmtree(root, ignore_errors=True)
    write_json(root, {"info": INFO, "assets": [
        {"filename": "App Icon - App Store.imagestack", "idiom": "tv",
         "role": "primary-app-icon", "size": "1280x768"},
        {"filename": "App Icon.imagestack", "idiom": "tv",
         "role": "primary-app-icon", "size": "400x240"},
        {"filename": "Top Shelf Image Wide.imageset", "idiom": "tv",
         "role": "top-shelf-image-wide", "size": "2320x720"},
        {"filename": "Top Shelf Image.imageset", "idiom": "tv",
         "role": "top-shelf-image", "size": "1920x720"},
    ]})
    # The art is 90% of the height: tvOS crops the edges a little as the icon
    # tilts, and the islands must stay whole.
    write_stack(root / "App Icon - App Store.imagestack", [1], 1280, 768, int(768 * 0.9), "tv")
    write_stack(root / "App Icon.imagestack", [1, 2], 400, 240, int(240 * 0.9), "tv")
    for name, width, stem in (("Top Shelf Image", 1920, "top-shelf"),
                              ("Top Shelf Image Wide", 2320, "top-shelf-wide")):
        folder = root / f"{name}.imageset"
        folder.mkdir(parents=True, exist_ok=True)
        images = []
        for scale in (1, 2):
            top_shelf(width * scale, 720 * scale).save(folder / f"{stem}@{scale}.png")
            images.append({"filename": f"{stem}@{scale}.png", "idiom": "tv", "scale": f"{scale}x"})
        write_json(folder, {"images": images, "info": INFO})
    print(f"wrote {root.name}")


def vision():
    root = ASSETS / "VisionAppIcon.solidimagestack"
    shutil.rmtree(root, ignore_errors=True)
    # The islands' outermost point sits 438px from the centre, inside the
    # 512px circle visionOS cuts, so the art keeps its full size.
    write_stack(root, [1], 1024, 1024, 1024, "vision", solid=True)
    print(f"wrote {root.name}")


MAC_SLOTS = [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2),
             (256, 1), (256, 2), (512, 1), (512, 2)]


def mac():
    flat = square_layer("Back").convert("RGBA")
    for which in ("Middle", "Front"):
        flat.alpha_composite(square_layer(which))
    folder = ASSETS / "AppIcon.appiconset"
    for px in sorted({size * scale for size, scale in MAC_SLOTS}):
        big = px * 4
        tile = round(big * 824 / 1024)
        mask = Image.new("L", (tile, tile), 0)
        ImageDraw.Draw(mask).rounded_rectangle([0, 0, tile - 1, tile - 1],
                                               radius=tile * 0.2237, fill=255)
        canvas = Image.new("RGBA", (big, big), (0, 0, 0, 0))
        canvas.paste(flat.resize((tile, tile), Image.LANCZOS), ((big - tile) // 2,) * 2, mask)
        canvas.resize((px, px), Image.LANCZOS).save(folder / f"mac-{px}.png")
    contents = json.loads((folder / "Contents.json").read_text())
    contents["images"] = [i for i in contents["images"] if i.get("idiom") != "mac"] + [
        {"filename": f"mac-{size * scale}.png", "idiom": "mac", "scale": f"{scale}x",
         "size": f"{size}x{size}"} for size, scale in MAC_SLOTS]
    (folder / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n")
    print("wrote mac icons into AppIcon.appiconset")


if __name__ == "__main__":
    tv()
    vision()
    mac()
