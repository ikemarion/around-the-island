# Cartoon stun-gun collectible

Approved reference and native Godot comparison views: [design record](../../../docs/art/stun-gun-concept/README.md).

`stun-gun.glb` is the runtime asset. Rebuild in Blender 5.2 with:

```text
blender --background --python tools/build_stun_gun.py
```

The builder uses Godot coordinates (Y up, muzzle toward -X), exporting to GLTF Y-up. The lightning medallions and vents exist on both Z sides so the spinning pickup reads from every approach. Geometry is centered over the existing saucer by the builder; `item_pickup.gd` uses 0.66 scale and a 0.23m visual lift without changing the pickup's collection sphere.

48,748 source triangles across the sculpt's parts. Godot generates mesh LODs on import. Materials are opaque rounded enamel, molded coral plastic and restrained gold/cyan, with a curved cyan lens and small molded glints; they do not depend on transparency or renderer-specific bloom. Material colors are tuned for the existing game lighting. No collision meshes, skeleton, animations, lights or gameplay/network scripts are embedded in the GLB.

Only the world collectible model is replaced. Existing firing, stun, inventory, HUD and projectile behavior are preserved; this update does not introduce a first-person held-gun system.
