# Quest System Fidelity and Integration Gate

**Reference:** owner-supplied Conquer Online Mobile Android client snapshot 1.1.2.3 (APK SHA-256 recorded in `CONQUER_ONLINE_FEATURE_PARITY_MATRIX.md`).
**Current decision:** BLOCKED / NOT APPROVED. Existing quest code is an offline prototype, not a source-faithful quest system.

## Non-negotiable target
Reconstruct the complete quest experience represented by the pinned mobile reference, including every quest family confirmed by the source. Preserve verified reference behavior and presentation subject to rights. Do not invent missing content or call a generic replacement identical. Private analysis and distributable rights are separate decisions.

## Coverage and record schema
Inventory main/storyline, side/optional, class/level/promotion/map/NPC/item/event-gated, repeatable, daily/weekly/timed/event/tutorial quests only where the pinned client confirms them. For each quest preserve source path/hash/key, category, localized title/text, giver and turn-in NPC, prerequisites, level/class/map gates, ordered objectives, target IDs and quantities, triggers/counters, branch conditions, failure/expiry/reset rules, rewards (items/quantities/Gold/XP/skills/unlocks), follow-up IDs, and every NPC/item/monster/map reference. Keep opaque fields opaque until the Android reader/schema proves their meaning.

## NPC presentation and hand-off
The full interaction is in scope: NPC model/identity/placement/facing/idle/talk animation; available/active/ready/locked markers; interaction prompt; offer/accept/decline/details/objective/progress/abandon/completion/reward-preview/claim/turn-in flows; quest tracker/journal/history/next-quest notice; and the NPC-to-player visual hand-off.

Map the speech/dialogue bubbles and their timing, position, tail/anchor, typography, portrait/icon, frame/background, buttons, choices and transitions. Where the reference shows an NPC quest-giving or turn-in bubble and a player response/confirmation, preserve them as distinct states; do not collapse them into a generic notification. Arabic RTL and available localization variants require review without incorrectly reversing icons, numbers or choice order.

Current `DialogueUI.tscn` is a plain bottom panel with labels/buttons, not evidence of reference bubble fidelity. Current `NPCBase.tscn` uses primitive meshes and `NPCBase.gd` hard-codes dialogue lines. These remain placeholders until source-backed NPC models, dialogue and UI references are mapped and reviewed.

## Runtime integration contract
Quest data must link by stable IDs to NPC catalogue/placement, character class/level/progression, world maps/portals/navigation, monsters/spawns/combat/death events, item catalogue/inventory/quest-item flags/drops, skills/unlocks, equipment/refinement/crafting where referenced, Gold/XP/reward ledger, achievements/titles/events and offline saves.

Use event-driven objective evaluation with explicit objective types and target IDs. Support multiple simultaneous quests if confirmed by the reference. Progress must be deterministic and idempotent. Prevent duplicate rewards after reload/event replay and invalid/partial turn-ins. Do not auto-grant rewards merely because an objective counter reaches its target if the reference requires returning to an NPC and explicitly claiming them. Persist active states, counters, branch choices, timers/reset timestamps and completion history as applicable.

## Source decoding status
The gameplay audit found `questinfo.dat` (default, Spanish and Arabic variants) and `taskitem_info.dat`, but candidate decodes are not accepted as Android 1.1.2.3 plaintext. Lua-like signatures under a seed borrowed from older PC research are only leads; `accepted_as_mobile_format=false`. The APK reader/cipher must be verified first. Candidate counts (341 keyed quest entries and 10 task-item rows) are not approved catalogue counts and must not enter runtime.

Current `QuestNavigationAgent.gd` has a small hard-coded sample chain (`quest_wolves`, `quest_wolf_alpha`, `quest_meteor_gather`, `quest_blacksmith_visit`, `quest_guardian`, `quest_level_10`, `quest_dragon`, `quest_final_sage`). It models one active quest, narrow kill/collect/talk/level objectives, hard-coded rewards and destinations. This is prototype content, not source parity.

## Evidence required per quest and UI state
1. Exact source path, SHA-256 and byte/record offset or stable source key.
2. Validated schema/version and field interpretation from the Android reader or cross-validated records.
3. Cross-reference validation for NPC, map, monster, item, reward and follow-up IDs.
4. Runtime implementation ID and automated acceptance test.
5. Screenshots/video for each distinct NPC/dialogue/quest state compared with reference captures.
6. Arabic RTL/localization review.
7. Offline save/reload, replay/idempotency and reward-ledger tests.
8. Rights/permission status for every source asset, text and UI element in distributable builds.

Statuses: `SOURCE_VERIFIED`, `SCHEMA_VERIFIED`, `MAPPED`, `IMPLEMENTED`, `VISUAL_REVIEW_REQUIRED`, `UNRESOLVED — NOT APPROVED`, `APPROVED`. A quest is approved only after all required evidence passes. No guessed NPC/quest mapping or generic substitute can pass as exact.

## Current acceptance
- QUEST-01: PARTIAL — prototype only; complete source catalogue not decoded.
- QUEST-02: PARTIAL — NPC/dialogue sample only; giver/turn-in mapping and branching not established.
- QUEST-UI-01: MISSING — reference quest offer, journal, tracker and reward UI not inventoried.
- QUEST-BUBBLE-01: MISSING — exact NPC/player bubble visuals, anchors, timing and transitions not mapped.
- QUEST-INTEGRATION-01: PARTIAL — basic navigation/event hooks exist; complete ID cross-linking and transaction-safe progression absent.
- Android source decode: BLOCKED — candidate quest/task-item decryption not validated against the 1.1.2.3 APK reader.

Do not approve this gate because the sample chain runs or the project builds.

## Additional runtime audit findings (2026-11-05)

- `NPCBase.interact()` calls `on_npc_talked(npc_id)` before dispatching the NPC role/dialogue. Therefore a talk objective can advance simply by interacting, without proving that the intended dialogue branch was selected or completed.
- `QuestNavigationAgent._complete_quest()` grants Gold/XP immediately when the objective counter reaches its target, then switches to `next_quest`. It does not require a mapped turn-in NPC, a ready-to-turn-in dialogue state, or an explicit reward-claim choice. This differs from the requested NPC hand-off flow and must be redesigned after source behavior is verified.
- The current navigation method chooses hard-coded map IDs and Vector3 destinations based on quest IDs. These are not source-linked objective locations.
- `DialogueUI.show_dialogue()` creates generic buttons and `_on_option_clicked()` emits an index, then closes the panel. There is no quest action payload, branch routing, speaker/portrait state, bubble lifecycle, or reward transaction binding.
- `NPCBase.gd` supplies three fixed lines per NPC role and the scene's NPC body is assembled from primitive cylinder/sphere meshes. Neither dialogue nor NPC appearance is accepted as reference content.

These findings are recorded as implementation gaps, not fixed by suppressing validation. The current runtime must remain prototype-only until the mobile source reader and quest records are validated and the complete interaction is implemented and tested.


## Follow-up source inspection: runtime and asset activation (2026-11-05)

### Quest runtime verified against current `main`
- `scripts/automation/QuestNavigationAgent.gd` is the active scene script. Its current database is a hard-coded sample chain; it has no source record keys or NPC giver/turn-in IDs.
- `_advance_objective()` calls `_complete_quest()` as soon as the objective counter reaches its target. `_complete_quest()` immediately grants Gold/XP, appends completion, and advances to the next quest. There is no explicit return-to-NPC or claim action.
- `on_npc_talked()` accepts only an NPC ID, and the NPC script emits this event before opening its generic dialogue. It cannot prove that the intended quest dialogue branch was completed.
- Quest navigation uses hard-coded destinations and coordinates; these are not tied to validated source objective/map IDs.
- Therefore the sample chain must not be treated as a valid reference implementation. Rework is blocked on validated Android 1.1.2.3 quest schema and source-to-runtime IDs; do not silently retrofit guessed turn-in NPCs.

### Character and mount activation verified against current `main`
- `AssetCatalog.gd` now requires an exact class and gender match through `CharacterModelMappingRules`. `PlayerController` keeps the current visual unless a candidate has renderable meshes, active materials, a skeletal rig with at least eight bones, and non-empty idle/movement clips. These runtime checks still do not prove source identity, complete anatomy, attachment transforms, or visual approval.
- `PlayerController._apply_character_model()` returns early if no verified mapping is found, leaving the original primitive character visible. If a model loads, it hides other visual children after instantiation; this is only safe once the mapped model passes provenance, materials, scale, rig/action and visual checks.
- `PlayerController._apply_mount_model()` now uses a strict lookup requiring `asset_role=complete_mount`, `mapping_status=verified`, and an exact `mount_item_id` match. The currently audited published PCKs contain zero converted mount GLBs and no runtime catalog, so no mount is presently eligible for activation. This removes arbitrary index selection; it does not complete mount coverage.
- `MainGame.tscn` and `Player.tscn` still contain primitive placeholder geometry. Do not hide or remove it until verified replacement scenes and runtime validation exist.
- Godot 4.3 supports importing glTF 2.0 scenes with mesh/material/animation data, but format support alone does not establish provenance or correct source mapping. The project must validate each source model, texture/material assignment, skeleton/action clip, scale and visual result before switching runtime visibility.

Current decision remains **BLOCKED / NOT APPROVED** for quest parity and visual asset replacement.


## Runtime correction and regression evidence (2026-11-05, latest implementation)

The prototype now has a safer intermediate turn-in lifecycle, but the fidelity gate remains BLOCKED:

- Objective completion enters a persisted ready-to-turn-in state; Gold/XP are not granted at the objective threshold.
- A reward is claimed only after the player talks to the configured turn-in NPC. Wrong-NPC interactions do not grant the reward.
- The next quest is not advanced until the turn-in reward is claimed. Completed-chain state is persisted and does not restart after reload.
- Quest navigation now exposes a target for the active objective and routes a ready-to-turn-in quest back to its configured NPC; the terminal completed chain has no further navigation target.
- Regression evidence from GitHub Actions run 42081897599: 140 total gameplay tests, 140 passed, 0 failed. This includes save/load of pending turn-in, wrong-NPC rejection, sage and blacksmith claim flows, level-gate handling, objective/turn-in navigation, completed-chain persistence, and strict complete-mount identity rejection tests, and rejection of unbound primitive character meshes.

Important limitation: the current sample NPC IDs and destinations (including npc_sage and npc_blacksmith) are implementation fixtures, not validated mappings from the Android 1.1.2.3 quest records. This correction fixes premature reward granting; it does not establish source parity, quest catalogue completeness, multiple simultaneous quests, accept/decline/abandon flows, dialogue branch selection, or the reference bubble/journal UI. Do not change the gate status to approved.
