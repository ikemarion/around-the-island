# Score Ribbons — approved concept B

Visual-only GLB meshes for `scripts/distant_scoreboards.gd`:

- `score-ribbon.glb`: beveled ceramic pennant, true boolean-cut recess and a recessed floor.
- `score-timer.glb`: mint enamel timer rim, cream face and four gold accents.
- `score-crown.glb`: hollow, lobed gold crown with rounded tips.

Rebuild with Blender 5.2: `blender --background --python tools/build_score_ribbons.py`.
Authoring helpers use Godot coordinates (Y up, front +Z); GLTF handles the conversion. All meshes are presentation only, with no physics shapes, game groups, skeleton or animation tracks.

Godot adds the shared capsule fill meshes and player-colored badges, Fredoka labels, crown motion and sparkles. Numeric score positions are fixed. Fill bars use one shared relative scale (`max(20, highest_active_score * 1.1)` seconds) and approach targets smoothly; the timer alone measures round progress. Exact totals remain visible to one decimal place.

Changing player counts centers only active slots without changing their colors or identity. Existing match snapshots supply every value; no new network fields or RPCs. Rounded end caps are resized independently of the fill's straight section, preserving their shape at all scores. Four instances share mesh resources; the inspected model is approximately 58.7k triangles per complete four-player display.
