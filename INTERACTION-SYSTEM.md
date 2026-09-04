# ATI Interaction System Workshop

## Goal

Interactions should be fast enough to use during a chase, physical enough to produce improvisation, and simple enough that players keep watching one another instead of managing an inventory.

The system should create soft-skill decisions:

- Which prop should I pull into the route?
- Do I risk slowing down to manipulate it?
- Where will my opponent be when this slippery patch activates?
- Can I bait my opponent into my own hazard without hitting it myself?

## Chosen input mapping

- **E / gamepad X:** Physical interact—highlight, grip, pull, and release props.
- **Q / right bumper:** Deploy the currently held quick item.
- **Left mouse:** Fire a held stun gun when the player's hands are free; throw a chair while gripping one.

These controls are now treated as the prototype default. Their behavior can still be tuned, but the two-channel split is accepted.

## Recommended first model

Give each player two distinct interaction channels:

### 1. Physical interact — hold **E** / gamepad **X**

- A forgiving short sphere cast selects the nearest highlighted prop near the center of the view.
- Holding the button grips the prop through a spring-like physics pull point in front of the player.
- Moving away pulls a chair out from the counter; lateral movement drags it into a route.
- Releasing the button drops the prop with its existing momentum.
- The prop remains physical and can catch against the counter, collide with players, or be stolen from a route.
- Carrying or dragging a chair applies a modest movement penalty, creating a real timing cost.

Hold-to-grip is recommended over tap-to-toggle because the player always understands why the prop is attached and can release it instantly during panic.

### 2. Quick item — tap **Q** / right bumper

- Each player has one visible quick-item slot, not a backpack or inventory grid.
- Tapping the button tosses the item a short distance along the ground in the facing direction.
- The first test item creates a temporary slippery patch.
- The patch affects its owner too and remains highly visible.
- Entering it preserves momentum while reducing braking and steering for a short duration; it should not simply stun or ragdoll the player.

This preserves soft skill: placement, approach angle, existing velocity, and recovery all matter.

**Implemented first item:** A bright slick is dropped at the player's feet, lasts eight seconds, and refreshes a short low-traction state while either player overlaps it. A four-second deployment cooldown keeps the debug version available without allowing every route to be covered instantly.

**Implemented first pickup:** A glowing pad supplies a one-shot stun gun. Walking over it temporarily replaces the slick in the single quick-item slot. The shot uses first-person aim, is blocked by arena geometry and props, and locks a hit player for just over one second before the gun is consumed. The pad restocks after ten seconds.

**Current spawn pool:** Every reset begins with a stun gun. Later spawns draw without repetition from Air Horn, Swap Bell, Springboard, Rewind Watch, Chair Cannon, and Emergency Door. Each pickup occupies the same one-use quick-item slot, while the slick remains the fallback when that slot is empty.

## Chair sources

Chairs should begin tucked into readable sockets around the counter rather than scattered randomly. A player can run past, hold Interact, and pull one into the route. Empty sockets clearly communicate that a chair has already entered play.

For the first test, chairs reset only between rounds. Later possibilities include slow respawning, a limited counter-side supply, or players returning chairs to sockets for another benefit.

## Interaction targeting

Use a hybrid first-person target check rather than a precise center-screen ray:

- Approximately 2 meters of reach
- A small sphere or cone around the reticle
- Prefer the closest valid prop with a clear line of sight
- Show a bright outline and concise prompt before input
- Never select through the counter

The generous target volume matters because interactions happen while both player and camera are moving quickly.

## Smallest implementation sequence

1. **Implemented:** Add highlighting and hold-to-grip for chairs.
2. **Current tuning:** Adjust spring strength, reach, throw impulse, drag penalty, and release momentum.
3. Move all chairs into counter-side sockets and test pulling them into routes.
4. **Implemented:** Add one cooldown-based debug slippery item and tune the movement effect.
5. **Implemented:** Limit players to one spawned item and add a readable, timed item source.

## Guardrails

- No inventory grid or radial menu during the prototype.
- No long interaction animation that removes movement control.
- No permanent obstacle placement; rounds reset the room.
- No hard stun from slippery patches.
- No prop should pin a player against a wall for more than a moment.
- Both the chair and slippery patch must be usable against their owner.

## Decisions still open

- Should a gripped chair stay fully physical or become more controllable while held?
- Should releasing while moving simply drop the chair or add a small throw impulse?
- Should the slick remain a rechargeable fallback, or eventually become a spawned item like the stun gun?
- Should the bot use interactions during the first implementation, or remain a clean movement opponent while Player 1 tests them?

## Current recommendation

The spring grip, deliberate throw, slick fallback, and seven spawned power-ups are now implemented. The slowing-field experiment was removed after its first pass. Next, identify which new items create route decisions versus merely creating spectacle, then cut or deepen them. The bot can jump route obstacles but still leaves item use to the human while the item set is young.
