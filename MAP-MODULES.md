# Modular house map

The v0.28 layout is garage → kitchen → living room. Each tile is 18 meters wide and 12 meters deep, with its floor at y=0. Centers are x=-18, 0, and +18. Two three-meter-wide passages at z=-3.5 and +3.5 connect each adjacent pair. The central furniture creates chase loops within each room.

## Editing in Godot

Open `scenes/main.tscn` to see the assembled house. The central `Arena` instance is `scenes/rooms/kitchen.tscn`; its `Rooms` child contains the living-room and garage scene instances. Existing kitchen scoreboard, spawner, island, and gameplay paths remain under `Arena`.

The two new scenes use `scripts/room_module.gd`, an `@tool` script that previews their geometry in the editor and generates the same geometry at runtime. Select a room instance to edit `theme`, `entrance_side`, or `room_id` in the Inspector. Changes to those fields rebuild the preview. Generated preview geometry is not saved into the scene; edit furniture dimensions and placement in the builder functions, or create another room scene/builder for a new theme.

The kitchen scene uses ordinary editable nodes for its furniture, floor, and dividers. Open that scene directly to change them.

## Adding or rearranging modules

1. Instance a room scene under `Arena/Rooms`, then move/rotate it using the 18×12 grid.
2. Give each instance a unique `room_id`. Names such as `LivingOttoman` and `GarageTire` are used to synchronize movable props, so duplicated IDs are not safe.
3. Match the passage positions and floor heights on both sides of every shared edge. The existing module builder supports one connected east or west edge; adding a through-room or a north/south connection requires extending `_build_boundary` on both adjoining modules. Moving a room alone does not automatically cut a doorway.
4. Keep passage openings and routes around major furniture clear. Stationary props use simple solid collision shapes; all current movable props use a 0.9-meter box to match the existing grab/throw behavior.
5. Place clear `Marker3D` nodes under each room's `PickupSpawns` child. The main scene automatically contributes their world positions to the single replicated spawner.
6. Tag floor bodies with `house_floor`. Navigation derives its bounds and walkable area from those bodies on startup; call `Arena/HouseNavigation.initialize()` after a runtime layout change. Static furniture and walls determine clearance. Moving props are intentionally excluded from the permanent navigation grid.
7. If expanding beyond the current house footprint, also resize `Arena/KillBox`, reposition the distant scoreboards, and review player spawn locations. The host's below-map fallback still rescues fallen players anywhere.

Room construction is deterministic: do not randomly rename, omit, or reposition static collision on individual peers. When changing the map distributed to friends, increment the build/protocol so every client uses matching geometry.

## Verification

Run `tests/modular_house_smoke.gd` with Godot's `--script` option to check passage clearance, floor and pickup coverage, navigation, prop identity/reset/replication, and fall recovery. Add `-- --check-bot` to exercise a live chase through all three rooms. Graphical mode also saves overview and room images to `build/network-test/`.

`tests/network_lifecycle.gd` with paired host/client instances checks joining, rejoining, item effects, and a moved garage prop across the network.
