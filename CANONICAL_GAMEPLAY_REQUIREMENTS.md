# CLASH OF LEGENDS — CANONICAL GAMEPLAY REQUIREMENTS
**Status:** Authoritative user-approved direction, 2026-11-02  
**Project:** Existing Clash of Legends repository; Godot 4.3 / Android, offline-first  
**Reference:** Conquer Online Mobile (used as a gameplay and visual reference)

This document records the owner's explicit requirements. It supplements the existing architecture and audit files; it does not replace the existing project, create a parallel game, or authorize destructive rewrites.

## 1. Product identity and non-negotiable direction
- Preserve the recognizable Conquer Online experience, progression logic, content categories, and visual identity as closely as can be lawfully and technically supported.
- The intended upgrade is primarily presentation quality: a polished 3D presentation, better lighting, materials, shadows, animation quality, effects, and a freely rotatable 360-degree camera. Do not redesign recognizable character silhouettes, outfit concepts, weapon identities, mount identities, monster identities, or world landmarks merely for novelty.
- Do not claim a feature is complete because a placeholder, sample, UI panel, or class stub exists. Completion requires functional implementation and acceptance evidence.
- Use original or properly licensed assets, data, names, dialogue, maps, and other protected content. Do not copy proprietary game files or reproduce protected expression without authorization. Where exact source assets/data are unavailable or not licensed, create compatible original replacements that preserve the broad gameplay role and clearly record the difference.

## 2. Offline-only operation
- The shipped game must be fully playable offline after installation and local asset installation. No account login, online matchmaking, live servers, cloud save dependency, real player connections, or runtime network dependency.
- Persist character progress, inventory, equipment, quests, gold, guild state, marriage state, and local world state on-device with safe backups.
- Any optional development-time asset transfer (Kaggle → Hugging Face Dataset → GitHub Actions/repository) is a build pipeline only, not a runtime game service.

## 3. Simulated population and social behavior
### Towns
- Target a maximum visible population of 30–40 simulated player-like characters in an ordinary town scene.
- Most town characters remain stationary at recognizable gathering/shop locations, as in the reference game's town behavior.
- At most 5–6 ordinary town characters should be moving at once; usually only one or two move. Avoid constant random wandering and pointless crowd animation.
- Do not create an always-moving crowd to make the town look busy.

### Hunting grounds and open areas
- Use sparse, purposeful population: occasional passers-by and a small number of hunters, with large quiet areas retained. Do not fill monster fields with crowds.
- Simulated entities should not autonomously initiate social behavior, spam messages, or run elaborate independent routines.
- They may participate in an interaction only when the player explicitly chooses a supported action, such as inviting a local simulated character to a party, trading with a merchant/player-like vendor, searching the Black Market, or interacting with a guild system. The action must be deterministic and locally simulated, not a real network session.
- Large crowds are reserved for explicitly scheduled local guild wars, tournaments, major battles, and special events. Spawn only the entities needed for the active event and release them afterward.

### Explicitly excluded social features
- No friends list.
- No player chat, private messages, world chat, trade chat, or simulated chat feed.
- Guilds, marriage, gatherings, guild wars, and tournaments remain included as offline local systems.

## 4. NPCs, shops, quests, and progression
- Preserve the reference role and placement logic of quest NPCs, merchants, blacksmiths, trainers, portal/teleport NPCs, and other service NPC categories.
- Implement the complete intended quest catalogue: main, side, secondary, repeatable, event, class/progression, and all other documented quest categories, with prerequisites, sequence, objectives, dialogue, rewards, and save persistence.
- Implement the Gang/Guild system as a real local system: founding/joining, ranks/permissions, contribution, membership, guild activities, guild competition/war, rewards, and persistence. Do not silently omit a distinct Gang mechanic if it differs from guild membership.
- NPCs must expose real interactions and quest/shop logic; a name label and a single generic dialogue are not sufficient.
- Preserve shop categories and useful vendor roles. Support local buying/selling with Gold.

## 5. Combat, hunting, and skills
- Implement the reference combat loop: target selection, normal attacks, skill attacks, hit/range rules, damage, defense, criticals, cooldowns, mana, buffs/debuffs, death, respawn, monster aggro, drops, experience, and progression.
- Build a complete skill catalogue per supported class, including unlock requirements, skill levels, costs, cooldowns, ranges, target rules, animation timing, and visual/audio effects. Current sample skills are prototypes, not proof of catalogue completeness.
- Implement hunting grounds with the appropriate monster populations, spawn rules, respawn timing, level ranges, drops, and boss/event encounters.
- Auto-Hunt and Auto-Loot, if retained, must be optional player-controlled features and must obey local rules and performance budgets.

## 6. Equipment, refinement, sockets, gems, fashion, and mounts
- Preserve the breadth and recognizable identity of weapons, armor, accessories, fashion/outfits, and their progression tiers.
- Implement refinement stages and their exact documented costs, success/failure behavior, stat changes, and stage-specific visual appearance. Weapon glow/emission must visibly change at the correct refinement stages; do not use one generic glow for every tier.
- Implement sockets/holes, socket creation rules, gem types, gem insertion/removal, stat bonuses, and visual indication where applicable.
- Include the full intended fashion/outfit catalogue and equipment appearance changes, not only stat records.
- Distinguish the starter/basic horse that the player receives and upgrades from the separate collectible/market/reward spirit-beast mounts. Preserve each mount's identity, model, movement/ride behavior, animations, and effects.
- Rare mounts and fashion items may be earned through gameplay, quests, events, achievements, or purchased from the in-game market using Gold. No real-money purchases, premium currency, cash shop, or external payment flow.

## 7. Economy and Black Market
- Gold is the only currency. Remove or avoid premium currency, CP, VIP diamonds, cash shop, real-money purchases, and payment integrations.
- Translate any reference-game paid/premium acquisition route into an explicitly defined Gold price, gameplay reward, quest, event, or achievement route. Do not leave a paid-only item unobtainable.
- Implement local merchants, buying/selling, player-like vendor simulation where selected, and a searchable Black Market with item availability, prices, purchase validation, and Gold transactions.
- Maintain economic balance and item rarity without requiring real-money spending.

## 8. Visual fidelity and 3D presentation
- Treat reference screenshots/video and legally usable source material as visual acceptance references.
- Improve material quality, lighting, shadows, environment detail, VFX, weapon glows, outfit readability, mount presentation, and camera control without changing the recognizable design language.
- Each generated 3D asset must be checked against its reference for silhouette, proportions, equipment placement, color blocking, and defining details. Reject or revise assets that drift from the intended identity.
- Keep gameplay readable on the Android baseline device. Visual upgrades must not overwhelm the screen or obscure combat/UI feedback.

## 9. Performance and storage
- Avoid decorative crowds and redundant assets. Reuse shared meshes, materials, textures, skeletons, and animation clips when valid.
- Use distance-based LOD, visibility culling, animation throttling for distant/static entities, instancing where suitable, and event-scoped spawning.
- Load optional asset packs on demand where supported; avoid keeping every high-resolution resource resident in memory.
- Optimize duplication and packaging, not content scope: do not delete required quests, NPCs, outfits, weapons, mounts, monsters, skills, or systems just to reduce file size.
- The 30–40 town population cap is a scene population target, not a requirement to ship 40 unique models. Reuse a controlled roster of compatible character rigs/looks.

## 10. Licensing and asset pipeline
- Hunyuan3D 2.1 outputs and model use are subject to Tencent's current Community License. Respect its territorial exclusions and all distribution/notice restrictions. The Egypt-configured Kaggle notebook does not by itself establish that every future distribution territory is permitted.
- The Hunyuan pipeline is for generating original or otherwise authorized assets. Do not feed generated outputs into training or improvement of another AI model where the license prohibits it.
- The asset pipeline remains: generation on Kaggle GPU → validated output assets (such as GLB) stored in the dedicated Hugging Face Dataset → existing GitHub Actions/repository integration. Keep the model-weights Kaggle Dataset separate from the output-assets Hugging Face Dataset.
- Never expose HF_TOKEN or other secrets in notebooks, logs, commits, artifacts, or game builds.

## 11. Acceptance gates
A system is not marked complete until:
1. It has a real implementation, not just a placeholder or mock UI.
2. Its data is connected to the relevant systems (NPCs, quests, combat, items, economy, progression, and saves as applicable).
3. It works offline with no runtime network dependency.
4. It has repeatable automated tests and a manual gameplay acceptance check.
5. It respects the population, storage, and Android performance budgets.
6. Its visual/content fidelity has been checked against lawful references.
7. Missing reference data or assets are explicitly listed rather than invented or reported as complete.

## 12. Known baseline gaps to resolve
The repository's current audit and code snapshot describe a prototype with a limited sample world, sample skills, a small NPC set, and simulated characters that wander. The current GameManager also contains generated local chat pools and a periodic chat-message signal, which conflicts with the owner's explicit no-chat requirement. These are known discrepancies to audit and correct; do not treat existing audit labels such as "complete" as proof that the expanded requirements in this document are satisfied.
