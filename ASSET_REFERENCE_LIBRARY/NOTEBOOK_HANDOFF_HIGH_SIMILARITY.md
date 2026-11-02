# Notebook Handoff — High-Similarity Asset Library

Project: Clash of Legends. This is an addendum to the asset source index, not a replacement for the game project.

## Non-negotiable art direction
The goal is the closest lawful visual match to the original Conquer Online visual language. Do not fill gaps with random generic fantasy assets. Prefer assets whose silhouette, proportions, palette, ornament, material, camera angle, and gameplay role match the target. If no close licensed asset exists, mark the slot as **NEEDS_CUSTOM_GENERATION** rather than silently using a poor substitute.

## Critical class progression — one character, two weapon forms
The Archer and Oriental Assassin must be treated as two stages/forms of the SAME character progression, not as unrelated character classes or two separate player characters.

Official Conquer Online Archer progression:
- Starting stage: **Intern Archer** (before the level-15 promotion).
- **Level 15:** promoted to **Archer**. This is the first qualified Archer stage; bow-and-arrow identity and assets begin here.
- **Level 40:** promoted to **Eagle Archer**. After this promotion, the Archer can transform into **Oriental Assassin** by equipping the required throwing-knife weapon. This is the key unlock point for the Assassin weapon family.
- Further Archer promotion milestones continue on the same character progression: **Level 70 Tiger Archer**, **Level 100 Dragon Archer**, **Level 110 Archer Master** (some newer promotion interfaces/editions list a level-120 master milestone; verify the exact target server/version before implementing rank caps).

The official class guide describes Oriental Assassin as the Archer's concealed identity, says the transformation becomes available after the level-40 promotion, and explains that the throwing knife is the required weapon; old Archer gear can still be used in Assassin form. Do not model Assassin as a brand-new character that starts at level 1.

### Correct asset acquisition priority
**P0-A — Oriental Assassin throwing knives (PRIMARY post-level-40 weapon family)**
- This is the primary weapon family after the level-40 Eagle Archer promotion and transformation unlock.
- Treat the weapon as a paired dual-knife set. Capture both blades together and each blade separately where possible.
- Inventory every identifiable appearance and upgrade tier.
- Preserve blade profile, point, spine, guard/handle, grip wrapping, paired orientation, ornament, material, colorway, and upgrade effects.
- Do not substitute generic western daggers unless no closer licensed alternative exists; mark poor matches for custom generation.

**P0-B — Archer bows (EARLIER progression and retained alternate form)**
- Collect every identifiable bow appearance and upgrade tier from the Intern Archer / Archer stages and later Archer progression.
- Preserve each distinct silhouette, limb curvature, grip, string, ornaments, material, colorway, and upgrade glow.
- Keep separate files/records per weapon and tier; do not collapse variants into one generic bow.
- Bow assets remain important because this is the same character's earlier form and Archer gear remains usable after transformation.

**P1 — Complete game visual coverage**
- Character classes and NPCs: outfits, robes, armor sets, helmets, hair, accessories, front/side/back views.
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
- `ASSET_REFERENCE_LIBRARY/Oriental_Assassin_Dual_Knives/`
- `ASSET_REFERENCE_LIBRARY/Archer_Bows/`
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
2. Build a class-progression inventory for ONE character: Intern Archer → Archer (15) → Eagle Archer (40) → Oriental Assassin form (unlocks after level-40 promotion); continue Archer promotion milestones at 70, 100, 110 (verify 120 master milestone against target server/version).
3. Acquire and model the dual throwing knives first for the post-level-40 Assassin form; acquire the bows second for the earlier Archer form and retained alternate use.
4. Inventory every weapon appearance and tier separately; retain original filenames.
5. Separate 2D reference images, textures, spritesheets, and importable 3D models.
6. Generate contact sheets for visual review, but retain the individual original files.
7. Rank candidates by the similarity rubric; do not accept low-similarity assets just to fill a category.
8. Reject unclear licenses and flag missing categories for custom generation.
9. Do not claim the library is complete until the actual binary assets, provenance manifests, and license files are present in the repository.

## Current status
This document defines acquisition and import requirements. It does not claim that any binary asset pack has already been downloaded or uploaded.
