# Sockling sculpt

`sockling-sculpt.glb` is the runtime geometry. It replaces the v0.50 stacked muzzle, separate jaw and bead-like fingers with continuous soft volumes. The Body mesh includes a `JawOpen` morph that deforms the lower lip and mouth lining together. The other parts retain local shoulder/hip anchors for the game's cosmetic animation.

Authoring source is `tools/sculpt-source/sockling-sculpt.blend` (excluded from Godot import/export by `.gdignore`). Rebuild using Blender 5.2:

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --factory-startup --python tools/build_sockling_sculpt.py
```

The builder performs voxel union, a real mouth boolean, lip beveling, smoothing, decimation and GLB export. Gameplay code never runs this builder or changes collision. `sockling_art.gd` adds the eyes, tongue and cuff and applies slot-specific materials. `sockling_fleece.gdshader` supplies stable object-space fibre bumps, knit stitches and foot-color transitions. Tiny cached instanced fibre tips are visible only within seven metres; the deforming lower lip and lower arms are excluded to avoid detached fuzz.

v0.52 adds `ElbowFlex` and `KneeFlex` shape keys. `sockling_motion.gd` blends cosmetic poses, samples deformed soles to keep grounded feet above their support plane, and anchors whole-puppet squash at the feet. It never writes player position, velocity, collision or camera. Host/bot motion uses floor contact; remote replicas use a short support query and existing velocity/crouch snapshots. Animation phase is local, not synchronized. Hidden or teleported actors reset pose history.

Animation checks: `tests/sockling_animation.gd`; pass `--animation-preview` with a graphical renderer to capture 270 actual Godot frames under `build/network-test/v052-animation/`. Run `python tools/encode_sockling_preview.py` (Pillow) to encode the sequence as animated WebP. `tests/sockling_network_animation.gd` runs a paired localhost test on UDP 27993 (`--animation-host` on the host instance).

Preview/verification: `tests/sockling_art_smoke.gd`. It renders the real level with temporary art-inspection cameras; loose obstacles and score displays are hidden only in these staged captures. Materials are approximations of the approved concept, not a claim of pixel-identical cinematic lighting.
