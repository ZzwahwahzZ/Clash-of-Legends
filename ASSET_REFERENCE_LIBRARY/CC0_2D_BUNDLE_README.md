# Clash of Legends — CC0 2D Reference Bundle

This bundle is built from the upstream **Tiddybub/2d-assets** collection.

## Verified source and rights
- Upstream: https://github.com/Tiddybub/2d-assets
- Upstream license: CC0 1.0 Universal, confirmed in the upstream `LICENSE` file.
- Upstream catalog: 1,101 asset packs; categories include characters/NPCs/animals, effects, fantasy/RPG, terrain/tiles, buildings/urban assets, UI and vehicles.
- Every imported pack retains its own `SOURCE.md` provenance record and original files from upstream.
- No Conquer Online proprietary files are copied into this bundle.

## Why this is a reference library, not a finished Conquer asset replacement
This is a broad 2D visual-reference pool. It contains mixed art styles and formats; it is not a single coherent Conquer Online model set, and it is not a 3D model archive. The notebook must inspect and select only visually relevant items, prioritize oriental/Chinese-fantasy silhouettes, and avoid treating unrelated modern/platformer art as final game assets.

## Coverage priorities for the notebook
1. Player character references and modular character/armor/clothing concepts.
2. Dual throwing knives/daggers for the user's Archer → Oriental Assassin progression, then bows and quivers.
3. Other playable classes: Trojan, Warrior, Taoist (Fire/Water), Ninja, Monk, Pirate, Dragon Warrior and any classes present in the target server version; include male/female forms, weapons, armor, helmets, robes and upgrade tiers.
4. NPCs: guards, merchants, trainers, quest givers, civilians and hostile humanoids.
5. Monsters, beasts, undead, demons, bosses and pets.
6. Mounts and companion animals.
7. Towns, buildings, gates, bridges, streets, forests, deserts, caves, islands, dungeons and terrain tiles.
8. Spell effects, portals, projectiles, loot, equipment icons, consumables and UI references.

## Download
The GitHub Actions workflow `.github/workflows/build-cc0-asset-bundle.yml` downloads the upstream CC0 repository and publishes a ZIP artifact named `clash-of-legends-cc0-2d-reference-library`. Download it from this repository's **Actions → Build CC0 2D Reference Bundle → Artifacts**.

The artifact is generated from the upstream repository at build time; it is not committed as a large binary into the game source repository.