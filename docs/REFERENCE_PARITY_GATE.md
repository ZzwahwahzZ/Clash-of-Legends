# Reference parity acceptance gate

A feature is NOT complete merely because it loads, runs, or passes a script test. It remains IN_PROGRESS until its original reference/source is identified, decoded where applicable, mapped to runtime behavior, integrated into the real game flow, tested, and visually reviewed in a rendered scene.

## Evidence states
- SOURCE_LOCATED: source asset/data file identified and hashed.
- SOURCE_PARSED: actual schema decoded and records validated; header/string probing does not count.
- MAPPED: source records/assets linked to runtime entities and behavior.
- IMPLEMENTED: working in the actual game flow, not a placeholder.
- AUTOMATED_PASS: relevant automated tests pass.
- VISUAL_REVIEW_PASS: rendered runtime capture compared against the approved Conquer Online Mobile reference.
- DEVICE_REVIEW_PASS: Redmi Note 11 / Android 13 test with FPS, memory, heat and stability evidence.
- ACCEPTED: all required evidence exists and no blocking defect remains.

## Required parity checks

### Items, monster drops, quests and upgrades
Decode original item definitions, monster drop rules, quest definitions, task-item requirements, gem data and refinement data. Preserve source IDs, categories, quantities, rates and associations when present. Every drop must trace to a parsed source record. No invented rates or generic fallback drops may be presented as original. Test monster -> drop -> inventory -> quest/upgrade end to end.

### Refinement and effects
Map each level and equipment type to original effect definitions/assets. Verify color, intensity, animation, timing, layering and attachment position in a rendered scene. Provisional color bands are scaffolding, not parity. Confirm real skeleton/socket attachment first.

### Characters, equipment, monsters and animation
Verify identity, proportions, scale, materials, rig, animation tracks, sockets and runtime attachment. Successful import or geometry counts are not visual acceptance. No blockouts, floating equipment, clipping, intersections or missing required animation in accepted content.

### Maps and audio
Convert source map data into playable rendered terrain. Parsed DMap counts are not rendered-map acceptance. Verify landmarks, walkability, collisions, camera, NPC/monster placement and transitions. Inventory and test source audio rather than silently omitting it.

### UI and gameplay
Compare layout, icons, labels, interaction flow and Arabic RTL against the reference. Every control must work. Test navigation, auto-hunt, loot filters, inventory, quests, trading and upgrades together for conflicts.

## Release policy
Internal APKs may be exported while work remains incomplete, but label them INTERNAL / PARITY NOT ACCEPTED. Do not call the game finished, faithful or production-ready until the relevant evidence gates pass. Keep the existing explicit asset redistribution permission gate disabled unless separately authorized.

## Known open blockers
- Gameplay binary schemas have only been probed, not decoded.
- Exact monster drop rates and full quest-material mappings are not yet established.
- Refinement glow uses provisional bands, not proven source effect mappings.
- Equipment-to-skeleton attachment and rendered parity are unverified.
- Primitive world blockouts and non-rendered map data remain.
- Runtime visual comparison and Redmi Note 11 performance review remain outstanding.
