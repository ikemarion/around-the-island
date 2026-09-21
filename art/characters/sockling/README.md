# Sockling sculpt

`sockling-sculpt.glb` is the runtime geometry. It replaces the v0.50 stacked muzzle, separate jaw and bead-like fingers with continuous soft volumes. The Body mesh includes a `JawOpen` morph that deforms the lower lip and mouth lining together. The other parts retain local shoulder/hip anchors for the game's cosmetic animation.

Authoring source is `tools/sculpt-source/sockling-sculpt.blend` (excluded from Godot import/export by `.gdignore`). Rebuild using Blender 5.2:

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --factory-startup --python tools/build_sockling_sculpt.py
```

The builder performs voxel union, a real mouth boolean, lip beveling, smoothing, decimation and GLB export. Gameplay code never runs this builder or changes collision. `sockling_art.gd` adds the eyes, tongue and cuff and applies slot-specific materials. `sockling_fleece.gdshader` supplies stable object-space fibre bumps, knit stitches and foot-color transitions. Tiny cached instanced fibre tips are visible only within seven metres; the deforming lower lip is excluded to avoid detached fuzz.

Preview/verification: `tests/sockling_art_smoke.gd`. It renders the real level with temporary art-inspection cameras; loose obstacles and score displays are hidden only in these staged captures. Materials are approximations of the approved concept, not a claim of pixel-identical cinematic lighting.
