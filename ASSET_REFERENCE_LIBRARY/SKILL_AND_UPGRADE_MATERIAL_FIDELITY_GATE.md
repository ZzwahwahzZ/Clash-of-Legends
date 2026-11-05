# Skills, Upgrade Materials & Progression — Fidelity Acceptance Gate

**Status: BLOCKED / NOT APPROVED**  
**Reference baseline:** owner-supplied Conquer Online Mobile Android client snapshot 1.1.2.3 (versionCode 123); regional/server content revision still needs confirmation.  
**Scope:** every class skill/spell, skill rank/upgrade, skill icon, animation, projectile, hit effect, buff/debuff, sound cue, upgrade/refinement material, gem, socket item, composition/refinery ingredient, protection item, and the visible result of every equipment upgrade stage.

## Owner's exactness requirement

The owner requires these systems to match the Conquer Online Mobile reference rather than merely resemble it:
- Skill catalogue and class assignment; original skill identity, names/labels, icon artwork, unlock conditions, ranks, level progression, costs, cooldowns, range, targeting, casting/attack timing, hit behavior, damage/effect rules, and animation/VFX/audio presentation.
- Skill upgrades: every rank/stage, required character/skill level, prerequisite, resource cost, success/failure rule, and the exact change in function and presentation.
- Upgrade/refinement materials: each distinct material's identity, icon/artwork, silhouette, palette, texture, rarity/grade, effects, stack/use rules, source-to-recipe mapping, and the exact purpose it serves.
- Equipment progression visuals: each refinement/composition/socket/gem/perfection/refinery/enchant/purify/soul/blessing/anima or other documented stage must show its own correct source-backed appearance/effect. Do not apply one generic glow or generic stone to unrelated tiers.
- No invented substitute may be marked as source-identical. If the exact source or evidence is unavailable, mark the entry `UNRESOLVED — NOT APPROVED`.

This is an item-by-item and skill-by-skill acceptance target, not a category-level assumption.

## Skill acceptance record (one row per skill and rank)

Each record must contain:
1. Stable skill ID, exact reference label/name, class(es), source client version and original data/source path.
2. Icon source and checksum; animation/motion identifiers; VFX/projectile/effect identifiers; sound identifiers where present.
3. Unlock and progression rules: character level, class/promotions, prerequisites, skill level/rank, upgrade materials/costs and caps.
4. Execution rules: target type, valid range/area, cast/startup/active/recovery timing, cooldown, mana/resource cost, hit/avoidance rules, damage/healing formula, status effects, duration, stacking, cleanse, and interruption behavior.
5. Runtime evidence for every rank: test case, expected/actual values, animation/VFX/audio capture, and offline behavior.
6. Source-vs-runtime visual comparison at equivalent camera framing. A data row or successful script call alone is not approval.

## Upgrade material acceptance record (one row per material and grade)

Each record must contain:
1. Stable item ID, exact reference label, grade/tier, item category, source version, original data path and checksum.
2. Original icon and, where applicable, 3D model/texture, animation or particle effect; retain exact silhouette, colors, markings, borders, highlights and material response.
3. Exact function and allowed targets: which equipment/skill/system accepts it, recipe or NPC/service, quantity, grade restrictions, level restrictions and compatibility rules.
4. Exact consumption, stack, trade/drop/store rules, Gold cost, success odds, failure outcomes, protection/return behavior and resulting stat/progression changes.
5. Visual progression evidence showing the correct material and resulting equipment appearance at every relevant stage.
6. Icon/source comparison and in-game screenshots; no generic placeholder icon, recolor, or one-material-fits-all mapping.

## Current evidence and known gaps (2026-11-05)

- `CONQUER_ONLINE_FEATURE_PARITY_MATRIX.md` records SKILL-01/02/03 as PARTIAL: CombatEngine has a skill database and sample checks, but the full reference catalogue, complete effects, and skill-to-animation/VFX/audio mapping are not established.
- The repository contains extracted audio files with names that appear skill-related (for example `magic*`, `ninjamagic*`, `skill_*zhanshi*`, `skill_*yongshi*`, and `pirate_skill_superfire*`). These are candidate source assets only; no complete verified mapping from each skill/rank to each audio file has been established.
- The existing C3 audit validated 1,060 PVR texture decodes and selected model/motion conversions, but it did not validate the full skill/effect/material catalogue or prove per-skill visual parity.
- The parity matrix records REFINE-01 as PARTIAL, SOCKET-01 and GEM-01 as MISSING, and CRAFT-01 as MISSING. Exact material records, recipes, rank-by-rank visuals, and item-to-source mappings remain unresolved.
- A source-index audit detected large weapon, armet, mount and texture tables, but some DBC table schemas were not validated. Counts or file presence are not a verified item/material catalogue.

## Required discovery and implementation sequence

1. Pin the exact mobile client build and identify any regional/content revision differences before extracting catalogues.
2. Safely decode and validate the skill, magic/effect, item, refinement, gem, socket, and recipe data schemas. Do not infer field meanings from names or record counts.
3. Build normalized registries with stable IDs and provenance. Join skill IDs to class tables, rank tables, animation/motion, effects, icons, sounds, and costs. Join material IDs to recipes, target item classes, grades, and progression results.
4. Generate explicit missing/unmatched reports. Never silently drop unknown records or fabricate mappings.
5. Implement the gameplay rules as deterministic offline systems, with automated per-entry tests and save/load coverage.
6. Import only exact source assets for which the intended use and distribution rights are documented. Where permission is not established, use the data as a research reference only and create separately identified original/authorized artwork; do not claim it is a carbon copy.
7. Produce per-skill and per-material visual evidence: icon sheets, animation/VFX clips, material turntables, refinement-stage comparisons, and device screenshots.
8. Test on the target Android device for readability, timing, frame rate, memory, touch interaction, and fully offline execution.

## Status vocabulary

- `SOURCE_VERIFIED`: source file/data and provenance are identified.
- `SCHEMA_VERIFIED`: record layout and field meanings are validated against the source.
- `MAPPED`: source IDs are joined to the correct skill/material, rank, animation, effect, recipe or equipment result.
- `IMPLEMENTED`: real offline behavior exists and automated tests pass.
- `VISUAL_REVIEW_REQUIRED`: source-to-runtime visual evidence is incomplete.
- `UNRESOLVED — NOT APPROVED`: missing source, schema, mapping, permission, or evidence.
- `APPROVED`: all relevant data, functional, visual, runtime, and rights checks pass for that individual entry.

A successful build, imported icon, non-empty skill list, or generic VFX is never sufficient for `APPROVED`.
