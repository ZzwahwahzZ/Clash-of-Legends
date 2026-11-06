# Unified asset-to-game integration graph

This document is the single integration map for all source-derived and project-owned content. Assets are not treated as independent folders: every accepted resource must be linked to the gameplay/UI system that consumes it.

## Existing runtime integration points verified in this branch

| Resource family | Existing runtime owner | Existing consumer / scene | Integration rule |
|---|---|---|---|
| Character models | scripts/core/AssetCatalog.gd + CharacterModelMappingRules.gd | scenes/characters/Player.tscn; scripts/player/PlayerController.gd | Complete character entries only; require verified class/gender mapping and correct scale/origin. |
| Class identity / selection | scripts/core/GameContentDatabase.gd + scripts/progression/ClassProgressionManager.gd | character selection UI (to be completed in scenes/ui) | One canonical class ID feeds model, weapon, skills, animation set, UI labels and progression. |
| Skeleton / bones / sockets | new validated C3 skeleton parser + Godot Skeleton3D/SkeletonProfile mapping | Player.tscn and character model scenes | Preserve source bone names, parent IDs, pivots and sockets. Do not infer hierarchy from mesh shape. |
| Skeletal motions | validated C3 motion parser -> AnimationLibrary / AnimationPlayer | scripts/animation/C3VatPlayer.gd is NOT a skeletal rig player | Bind idle/walk/run/attack/skill/hit/death clips to the verified rig. Keep VAT as a separate deformation path. |
| VAT deformation | scripts/animation/C3VatPlayer.gd | MeshInstance3D + C3 VAT shaders | Use only for source-mapped vertex animation textures with validated vertex IDs and matching normal data. |
| UI textures / FUI / atlases | UI asset importer + explicit screen mapping | scenes/ui/* and scripts/ui/* | Rebuild as responsive Godot Control scenes; preserve icon-to-action and screen-to-data bindings. |
| Audio / music / voice | scripts/core/GameAudioManager.gd | player, combat, NPC, quest and world systems | Create cue manifest with event ID, source file, codec, duration and intended caller. Avoid filename-only guesses. |
| Quest / NPC / monster / item data | scripts/core/GameContentDatabase.gd + GameManager.gd | scenes/npcs, scenes/enemies, HUD quest banner and dialogue | Parse tables into typed IDs; link quest -> NPC -> map -> objective -> reward -> UI. |
| Maps / world props / effects | AssetCatalog + ResourcePackManager | scenes/world and combat/world scenes | Preserve map identity, coordinates, collision/navigation and references to NPCs/monsters/portals. |

## Dependency graph (the order is intentional)

1. **Source intake:** archive hash, recursive inventory, CRC, nested archive extraction, file signatures.
2. **Format recognition:** identify APK/ZIP/PAK/C3/FUI/DBC/INI/audio/texture/model signatures. Unknown data remains quarantined.
3. **Schema recovery:** extract class/config tables and validate skeleton/motion/UI/gameplay record boundaries. Keep fixtures and parser versions.
4. **Asset conversion:** standard FBX/DAE/OBJ/BLEND -> GLB; source C3 -> validated mesh + rig + clips or VAT only when the format proves that path; textures -> Godot-compatible images; audio -> probed source plus optional lossless/target conversion.
5. **Identity mapping:** stable IDs join character class, gender, model, rig, motion set, equipment slots, skill animations, voice/SFX and selection-card UI.
6. **Scene integration:** load accepted assets through AssetCatalog and existing scenes/scripts; connect UI controls to real gameplay actions.
7. **End-to-end validation:** select each class -> spawn correct model -> play idle/walk/run/attack/skill/hit/death -> equip weapon -> show correct icons -> play matching SFX -> open quest -> talk to NPC -> complete objective -> receive reward -> persist save.
8. **Visual acceptance:** inspect proportions, rig deformation, clip transitions, material/texture fidelity, UI readability/RTL and audio sync on desktop and Android target.

## Promotion gates

- **Discovered:** present in a verified archive index.
- **Extracted:** bytes extracted safely; hash recorded.
- **Parsed:** format and schema validated with fixtures.
- **Converted:** conversion output loads and preserves expected content.
- **Mapped:** linked to stable project IDs and the correct runtime consumer.
- **Integrated:** visible/usable in a Godot scene and connected to dependent systems.
- **Accepted:** passes runtime, visual and Android performance checks.

No asset skips a gate. A successful ZIP test does not prove a C3 parser; a successful GLB import does not prove a correct rig; a UI image does not prove that its buttons work.

## Current verified state and boundaries

- Existing project code already has AssetCatalog, CharacterModelMappingRules, GameContentDatabase, ClassProgressionManager, GameAudioManager, MainHUDController and C3VatPlayer integration points.
- The catalog path expected by AssetCatalog is res://resource_stage/world/resource_catalog.json, but that file is not currently present in this branch listing. It must be generated from the reviewed integration manifest, not filled with guessed paths.
- The new external forensic toolchain is under tools/asset_forensics and its Colab runner stages extracted files privately in Google Drive.
- Source-derived Conquer files and converted derivatives remain excluded from public PCK releases by PUBLIC_RESOURCE_DISTRIBUTION_POLICY.md until redistribution rights are established. The private working copy can still be assembled for review and testing.
- Do not merge experimental assets or workflow output into main until the visual and functional acceptance gates pass.
