"""Encode native Godot frames as animated WebP (requires Pillow).
Run after tests/sockling_animation.gd --animation-preview. No generated frames
or interpolation: this is simply the engine capture played back at 30 fps.
"""
from pathlib import Path
from PIL import Image

root = Path(__file__).resolve().parents[1]
frames = root / "build" / "network-test" / "sockling-animation-frames"
images = []
for i in range(270):
    with Image.open(frames / f"frame-{i:03d}.png") as image:
        images.append(image.convert("RGB"))
output = root / "build" / "network-test" / "sockling-animation.webp"
images[0].save(output, save_all=True, append_images=images[1:],
               duration=[33,33,34]*90, loop=0, quality=88, method=4)
with Image.open(output) as check:
    assert check.n_frames == 270
print("SOCKLING_PREVIEW_VIDEO PASS", output, output.stat().st_size)
