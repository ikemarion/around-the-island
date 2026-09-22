# Reference-driven Sockling refinement

`reference-comparison.png` is a Godot screenshot with the approved concept in
a UI panel beside the real player model. The player uses the same meshes,
materials, idle pose and lighting as the game. No paint-over or replacement
studio lights are used. `reference-angle.png`, `front.png`, `side.png` and
`lineup.png` show other views, including all four slot colors.

`sockling-animation.webp` is a nine-second native Godot pose capture at 30 fps:
idle, walk, run, jump/landing, carry, crouch, slide, stun. Locomotion is shown
in place; the jump follows the game's ballistic arc. It is encoded from actual
engine frames with no generated or interpolated frames.

This pass specifically targets the broad muzzle, smaller seated eyes, long
noodle arms, chunky three-lobed hands, splayed feet, sock heel, slouched stance,
thick knit cuff and matte curly fleece. The concept's soft cinematic lighting
still differs from the actual directional lighting used in the arena.

Captures hide HUD, scoreboards and loose obstacles for inspection. These are
staged art/animation checks, not recordings of live matches. These preview
files are excluded from game exports.
