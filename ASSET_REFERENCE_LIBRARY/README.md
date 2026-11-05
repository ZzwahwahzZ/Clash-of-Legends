# Clash of Legends — Visual Reference Asset Sources

This folder tracks visual-reference assets for the game's art/3D-generation workflow.

## Selection and fidelity rules
- **Paid/premium Conquer Online Mobile appearance is a locked fidelity target.** Weapons, armor, helmets, clothing, fashions, mounts, mount tack/ornaments, and their visual effects must retain the exact source design, silhouette, colors, engravings, patterns, and material details. Do not recolor, simplify, redesign, or substitute these items with a merely similar asset.
- **Skills and progression materials are also locked fidelity targets.** Preserve the complete reference skill catalogue, class assignments, icons, ranks, unlocks, costs, cooldowns, targeting, execution behavior, animation/VFX/audio, and rank-by-rank progression. Preserve each upgrade/refinement material, gem, socket item, icon, grade, recipe, purpose, consumption rule, and the distinct appearance of every resulting equipment stage. No generic skill/effect/material substitute may be presented as identical.
- Exact source files may be used only where the project owner has the rights/permission required for the intended use and distribution. Keep proprietary originals out of this public repository and public releases unless redistribution rights are explicitly established.
- If the exact source asset or permission is unavailable, mark that item **UNRESOLVED — NOT APPROVED**. A licensed substitute may be used for unrelated/non-premium content only when it does not violate the locked premium-asset requirement.
- Preserve provenance for every imported file: source URL/archive, original path/name, owner, license/permission evidence, retrieval date, checksum, transformations, and intended use (reference, private build, or distributable build).
- Technical conversion or a successful render is not visual approval. Every item must pass source-to-render comparison and texture/UV/material review before acceptance.

## Initial verified source candidates

| Game category | Substitute/source | License evidence | Intended use |
|---|---|---|---|
| Swords, daggers, elemental weapons | FANTASY-sword-set by MELLE on OpenGameArt | CC0 stated on the asset page | Weapon shape/material/color references; not Conquer-specific designs |
| Medieval/fantasy towns | Kenney Fantasy Town Kit | CC0 stated on pack listing | Building silhouettes, streets, walls, town props |
| Fantasy/medieval environments | Kenney Retro Fantasy Kit | CC0 stated on pack listing | Castle/town architecture and prop references |
| Humanoid character bases | Kenney Animated Characters | CC0 stated on pack listing | General proportions/rigging reference only; not a replacement for detailed MMORPG hero art |
| Broad 2D RPG/fantasy categories | Tiddybub 2d-assets collection | Repository states all included packs are CC0 and include per-pack SOURCE.md | Candidate pool for creatures, enemies, items, effects and tiles; import only after checking each pack's SOURCE.md |

## Source pages
- FANTASY-sword-set (CC0): https://opengameart.org/content/fantasy-sword-set
- Kenney Fantasy Town Kit: https://kenney.nl/assets/fantasy-town-kit
- Kenney Retro Fantasy Kit: https://kenney.nl/assets/retro-fantasy-kit
- Kenney Animated Characters: https://kenney.nl/assets?series=Animated+Characters
- Tiddybub 2D assets (CC0 collection): https://github.com/Tiddybub/2d-assets

## Planned reference groups
1. Heroes and NPCs — front/side/back views where available; armor, helmets, robes, hairstyles.
2. Weapons and shields — sword, blade, dagger, bow, staff, mace, axe, spear, shield; elemental variants.
3. Creatures and bosses — beasts, undead, dragons, insects, spirits; multiple angles and scale references.
4. Mounts and pets — horse-like mounts, flying mounts, companion creatures.
5. Environments — towns, castles, forests, deserts, caves, dungeons, islands.
6. Effects and objects — spell effects, portals, crystals, loot, chests, consumables, UI icons.

## Important status
This is a source-and-license index, not a claim that the full image bundle has been imported. Binary image/model assets will be added only after their original files and licenses are verified. Do not treat an image preview or a web search thumbnail as a redistributable source file.

## Detailed acceptance gates
- `PAID_ASSET_VISUAL_FIDELITY_GATE.md` — per-item visual/source/rights acceptance for paid equipment and mounts.
- `SKILL_AND_UPGRADE_MATERIAL_FIDELITY_GATE.md` — per-skill, per-rank, per-material and per-upgrade-stage functional and visual acceptance.
