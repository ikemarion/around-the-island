# Saturday morning cartoon — first playable art pass (0.24)

Visual-only Godot geometry kit in scripts/cartoon_art.gd, with tile and outline shaders. This is a first implementation inspired by the approved concept, not a reproduction of the full illustrated scene.

Added teal island cabinetry and cream countertop, tiled floor, orange upholstered chairs, taped cardboard boxes, capsule-character faces/hands/shoes with dark outlines, and an equipped first-person air horn. The horn is cosmetic and appears only for the equipped item in first person; existing gameplay remains authoritative. Character details inherit the body mesh's visibility for invisibility and first-person hiding.

Original collision shapes, masses, spawn positions, obstacle names and network protocol remain unchanged. Chairs fit the existing 0.9m collision envelope; detailed legs do not introduce new collision gaps. The floor and arena boundaries remain the same size. No decorative room walls were added, preserving outside views and the existing fall-off rules.

New permanent cartoon_art_smoke test checks prop existence, collision envelopes, invisible character children and horn visibility, and captures rendered previews. Further work: smoother/beveled prop geometry, animation, consistent art for the remaining power-ups, environmental backdrop, and a performance pass. Assets are native procedural meshes, not generated-image textures or Blender exports.

The outstanding 400ms/5%-loss item activation issue in LATENCY-0.23.md is not addressed by this visual-only update.
