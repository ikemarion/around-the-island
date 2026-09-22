"""Encode 270 native Looper engine captures as a nine-second WebP.

Run after tests/looper_art.gd --looper-animation-preview. This does not generate,
interpolate, retouch or crop frames; it encodes the actual Godot viewport.
"""
from pathlib import Path

from PIL import Image


root = Path(__file__).resolve().parents[1]
frames = root / "build" / "network-test" / "looper-animation-frames"
images = []
for index in range(270):
    with Image.open(frames / f"frame-{index:03d}.png") as frame:
        images.append(frame.convert("RGB"))
output = root / "build" / "network-test" / "looper-animation.webp"
images[0].save(output, save_all=True, append_images=images[1:],
               duration=[33, 33, 34] * 90, loop=0, quality=88, method=4)
with Image.open(output) as verification:
    assert verification.n_frames == 270
print("LOOPER_PREVIEW_VIDEO PASS", output, output.stat().st_size)
