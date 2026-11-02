# Notebook Handoff — High-Similarity Asset Library

Project: Clash of Legends. This is an addendum to the asset source index, not a replacement for the game project.

## Non-negotiable art direction
The goal is the closest lawful visual match to the original Conquer Online visual language. Do not fill gaps with random generic fantasy assets. Prefer assets whose silhouette, proportions, palette, ornament, material, camera angle, and gameplay role match the target. If no close licensed asset exists, mark the slot as **NEEDS_CUSTOM_GENERATION** rather than silently using a poor substitute.

## Priority order

### P0 — Archer weapons
- Collect every identifiable bow/crossbow appearance and upgrade tier used by the Archer class.
- Preserve each distinct silhouette, limb curvature, grip, string, ornaments, material, colorway, and upgrade glow.
- Keep separate files/records per weapon and tier; do not collapse variants into one generic bow.

### P0 — Eastern Assassin dual throwing knives
- This is a paired weapon set: capture both blades together and each blade separately where possible.
- Collect all identifiable weapon appearances and upgrade tiers.
- Preserve blade profile, point, spine, guard/handle, grip wrapping, paired orientation, ornament, material, colorway, and upgrade effects.
- Do not substitute generic western daggers unless no closer licensed alternative exists; mark poor matches for custom generation.

### P1 — Complete game visual coverage
- Character classes and NPCs: outfits, robes, armor sets, helmets, hair, accessories, front/side/back references.
- Mounts and pets: horses, tigers, dragons, flying mounts, companion creatures, saddles and barding.
- Buildings and settlements: oriental/Chinese-inspired houses, palaces, gates, bridges, markets, temples, walls, street props.
- Biomes/maps: deserts, dunes, oases, rocky terrain, forests, mountains, caves, islands, dungeons, water and sky.
- Monsters and bosses: creatures, humanoid enemies, undead, beasts, dragons, insects, spirits.
- Other weapons/gear: swords, staffs, axes, spears, shields, armor pieces and accessories.
- Effects and items: skill VFX, aura, portals, loot, chests, crystals, potions, crafting items, inventory icons and UI art.

## Similarity scoring
For every candidate asset, record a 0–5 score for:
1. silhouette/proportions
2. detail/ornament
3. palette/material
4. cultural/style match (especially oriental/Chinese-inspired elements)
5. camera/view suitability
6. gameplay role/scale

Prioritize the total score, but do not let a high score in one dimension hide a major mismatch in silhouette or style. Keep a source/reference image and a short comparison note with each candidate.

## Legal and provenance requirements
- Only add original binary files when the source clearly permits redistribution and the license is recorded.
- Keep the creator, exact source URL, license name/version, and any attribution text alongside each imported pack.
- A web preview, thumbnail, search result, or screenshot is not proof of redistribution permission.
- Do not copy proprietary Conquer artwork or extract it from game files for redistribution. Use it only as a private comparison reference where lawful; create or source independent alternatives.
- Preserve each pack's own license file and source metadata.

## Suggested folder layout
- `ASSET_REFERENCE_LIBRARY/Archer_Bows/`
- `ASSET_REFERENCE_LIBRARY/Eastern_Assassin_Dual_Knives/`
- `ASSET_REFERENCE_LIBRARY/Characters_Outfits_Armor/`
- `ASSET_REFERENCE_LIBRARY/Mounts_Pets/`
- `ASSET_REFERENCE_LIBRARY/Buildings_Cities/`
- `ASSET_REFERENCE_LIBRARY/Deserts_Biomes_Maps/`
- `ASSET_REFERENCE_LIBRARY/Monsters_Bosses/`
- `ASSET_REFERENCE_LIBRARY/Other_Weapons_Gear/`
- `ASSET_REFERENCE_LIBRARY/Effects_Items_UI/`
- `ASSET_REFERENCE_LIBRARY/Source_Manifests/`

## Notebook workflow
1. Read this handoff and the adjacent README before importing anything.
2. Build an inventory by category and variant/tier; retain original filenames.
3. Separate 2D reference images, textures, spritesheets, and importable 3D models.
4. Generate contact sheets for visual review, but retain the individual original files.
5. Rank candidates by the similarity rubric; keep P0 weapon variants separate.
6. Reject unclear licenses and low-similarity assets. Flag missing categories for custom generation.
7. Do not claim the library is complete until the actual binary assets, provenance manifests, and license files are present in the repository.

## Current status
This document defines acquisition and import requirements. It does not claim that any binary asset pack has already been downloaded or uploaded.
