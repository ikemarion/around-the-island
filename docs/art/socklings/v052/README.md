# Sockling animation preview

`sockling-animation.webp` plays a nine-second native Godot capture at 30 fps:
idle → walk → run → jump and landing → carry → crouch → slide → stun.

These are staged pose samples in the actual level, with loose props and HUD
hidden. Locomotion is shown in place so the character stays in frame; the jump
uses the game's ballistic arc. The video is encoded directly from engine
frames, not generated or interpolated artwork. The same pose code runs in game.

Authoring scripts: `tests/sockling_animation.gd` and
`tools/encode_sockling_preview.py`. Preview assets are excluded from exports.
