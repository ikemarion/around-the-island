# Future passes

## Approved concept implementation, one piece at a time

- 0.33: mockup ghost, pocket watch, and air horn completed. Continuous scalloped sheet, porcelain coloring, gold watch case with twelve ticks and raised hands, teal loop; coral/teal air horn with hollow cream trumpet and embossed gust badge. Held horn reuses pickup geometry. All four mockup collectibles use restrained warm lighting and slower float/spin. Other collectibles retain their existing designs; their materials no longer self-illuminate.

- 0.32: swap bell + ceramic spawn saucer. Revolved silhouettes, gold material, cream lip, teal base, recessed ready ring, subdued empty state, slower bell bob/spin, two sparkles. Spawn labels hidden. Collision remains nonblocking.
- Next: ghost, pocket watch, air horn, then remaining collectibles to match the approved cream/teal/coral/gold mockup.
- Pending: replace explicit spark banner with subtle gold vignette; restore angular cardboard-box art. These have not been implemented in this focused bell/pedestal pass.
- Reference: generated_images/01a0593e-5e63-7d63-b8d1-dbe462487ed2/exec-a47f3a07-f3d3-4ebc-95cf-224be7fc9895.png under the user's Codex directory.

## Visual pass 0.31

- Shared cached bevel geometry across kitchen furniture, room props, cabinetry, and pickup models; collision and network identities unchanged.
- Consistent toon shading and softer highlights, smoother spheres, upholstery buttons, toy belly patch, car trim, tire treads.
- Toy ray-gun stun pickup and rounded kitchen-tile pocket wall.
- Local spark badge, gold corner accents, and acquisition/loss text follow replicated ownership; hidden in menus.
- Existing readable bell, ghost, watch, crown, and doorway silhouettes retained. Further bespoke art polish remains possible.

Current tuning (0.30.1): push/pull impulse reduced from 50 to 15, a 70% reduction. Charged throws and air horn unchanged. Protocol remains 10; host determines physics strength.

- Visual object pass: revisit silhouettes, scale, rounded cartoon styling, and consistency across kitchen, living room, garage, and power-ups.

# 0.30 changes

- Removed bungee hook from gameplay and removed the default slick trap.
- M1 / RT pushes obstacles with 10× the original impulse (50).
- M2 / LT pulls targeted obstacles toward you with matching impulse.
- Charged throws and air horn strength are unchanged.
- Protocol 10: all players need 0.30.

# Obstacle controls (0.29)

- Hold E / X to grab; release to drop. Wider reach and sticky target selection.
- Empty-handed M1 / RT shoves the targeted prop (stun gun retains fire priority).
- While grabbing, hold M1 / RT for up to one second, then release for a throw up to 2.5 times normal strength.
- Gravity-compensated, damped carry spring with a wall-aware anchor; physical collisions remain enabled.
- Host/solo: hold Y / Triangle for one second to restart; R still works.
- Protocol 9: all players must use the same build.
