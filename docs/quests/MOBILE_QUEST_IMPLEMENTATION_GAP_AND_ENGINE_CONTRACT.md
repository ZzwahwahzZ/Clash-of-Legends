# Conquer Online Mobile Quest System — Evidence Gaps and Implementation Contract

Status: research and architecture only; no gameplay content in this document is approved for activation.

## 1. Evidence boundary

Primary content evidence is the official Conquer Online Mobile guide:
- Guide index: https://comobile.99.com/guide/info/info.shtml
- Main Quest in Spheres: https://comobile.99.com/guide/2024-03-19/main_quest_in_spheres.shtml
- Bounty Hall: https://comobile.99.com/guide/info/quests/2023-01-31/daily_-_bounty_hall.shtml
- Farmland Defence: https://comobile.99.com/guide/info/quests/2023-01-31/daily_-_farmland_defence.shtml
- Hunting Battle: https://comobile.99.com/guide/info/quests/2023-01-31/daily_-_hunting_battle.shtml
- Mayhem Land Crusade: https://comobile.99.com/guide/info/quests/2023-01-31/daily_-_mayhem_land_crusade.shtml
- Chi Canyon: https://comobile.99.com/guide/info/quests/2023-01-31/trials_-_chi_canyon.shtml
- Battle Dojo: https://comobile.99.com/guide/info/quests/2023-01-31/trials_-_battle_dojo.shtml
- Rune Mountain: https://comobile.99.com/guide/info/quests/2023-01-31/trials_-_rune_mountain.shtml
- Class Epic and Inspiring quest pages are recorded individually in data/quests/mobile_official_research_catalogue.json.

The public Conquer Online development wiki documents older/classic client file formats and message structures. It is not proof of Mobile's internal implementation and must not be copied as Mobile source code. It may be used only as a protocol/architecture lead after compatibility is independently established:
https://conquer-online.github.io/wiki/

## 2. Current implementation gap

The existing QuestNavigationAgent is a minimal prototype. It supports a single active quest and a narrow objective set (kill, collect, talk, reach level), one integer progress counter, one turn-in NPC and simple gold/XP rewards. It cannot faithfully represent the Mobile guide's published systems yet.

Known gaps:
- ordered multi-step story chains and progression gates;
- dialogue options, conditional branches, prerequisites and alternate outcomes;
- item possession, item submission, item transformation and retry/failure branches;
- distinct target map, region, monster, boss and interaction-object identities;
- multi-objective and simultaneous counters;
- timers, scheduled windows, attempt quotas, daily accumulation/caps and claim-once flags;
- score/ranking rounds, wave progression, stage thresholds and timed boss spawns;
- class/level/rebirth eligibility;
- entry-button activities with no published NPC giver;
- reward bundles, reward claim state and inventory capacity checks;
- save/resume, offline daily reset policy and deterministic local activity scheduling;
- Arabic/English dialogue presentation without changing canonical source IDs.

No quest content should be activated by this prototype until these gaps are addressed.

## 3. Required runtime modules

1. QuestCatalogRepository
   - Loads source-backed records and source evidence metadata.
   - Rejects duplicate project keys, missing canonical references, invalid schema versions and records not approved for runtime.
   - Never invents source IDs from translated names.

2. QuestDefinition
   - Stable project key plus nullable source quest ID.
   - Category: main, daily, class_epic, class_inspiring, trial_activity, event, or other only when source evidence establishes it.
   - Eligibility predicates: level, class, rebirth, prerequisites and time window.
   - Ordered steps and optional branches.
   - Map/NPC/monster/item/object references are foreign keys to independently verified registries, never free-form invented scene paths.
   - Rewards are structured item/currency/experience bundles with source evidence.

3. QuestStateStore
   - Per-character accepted, active, step index, objective counters, branch decisions, ready-to-claim, claimed, failed and abandoned states.
   - Persist daily counters, attempt counts, cooldowns, claim flags and timestamps.
   - Store only IDs and state; localized strings remain in catalogues.

4. QuestEventRouter
   - Consumes typed gameplay events: NPC interaction, dialogue choice, map entered, region reached, monster defeated, boss defeated, item acquired, item submitted, object activated, timer elapsed, score updated, wave cleared, stage threshold reached and level/class/rebirth changed.
   - Events advance only objectives whose canonical IDs and conditions match.

5. QuestConditionEvaluator
   - Evaluates prerequisites, inventory requirements, class/level/rebirth gates, map identity, time windows, attempt limits and branch conditions.

6. QuestActivityController
   - Supports timed/scored activities and multi-wave encounters separately from narrative dialogue quests.
   - Uses source-backed schedules, scoring, stage transitions and claim rules.
   - Does not invent an offline replacement for a server ranking or server-time event. Such behavior needs an explicit project design decision and must be labelled as an adaptation.

7. QuestRewardService
   - Validates claim state and inventory capacity, grants each reward exactly once, then persists the claim.
   - Gold-only project economy rules override source CP purchase mechanics; excluded mechanics must not be silently replaced.

8. QuestNavigationBridge
   - Resolves only verified map/NPC/target registry IDs.
   - Requests navigation to a verified interaction approach point and confirms physical arrival/interaction separately.
   - No fallback NPCs or fabricated destinations.

9. QuestUI
   - Quest list, details, dialogue, objective tracker, map marker, activity entry, progress, reward and claim states.
   - Arabic RTL by default; English secondary.
   - UI labels never become gameplay identifiers.

## 4. Data model requirements

Every runtime candidate must include:
- project_record_id (internal stable key);
- source_quest_id (nullable until proven);
- source_title and source_uri;
- source_version/date and evidence status;
- category and lifecycle state;
- eligibility conditions;
- ordered step definitions;
- objective type, canonical target ID, required count/score/duration;
- map/NPC/monster/item/object IDs where established;
- dialogue node IDs and branch conditions where established;
- reward bundle and claim semantics;
- repeat/reset/attempt rules;
- localization keys;
- unresolved fields list.

A record with unresolved gameplay-critical fields remains RESEARCH_ONLY_NOT_RUNTIME_APPROVED. Do not fill unknown fields with guessed defaults.

## 5. Mobile-specific catalogue findings to expand

The official Mobile guide's Quests navigation includes:
- Daily Quests: Bounty Hall, Farmland Defence, Hunting Battle, Mayhem Land Crusade.
- Welfare: Sign In, Daily Packs (track separately as reward/claim systems until confirmed as missions).
- Trials: Chi Canyon, Battle Dojo, Rune Mountain.
- Epic Quests: Ninja, Taoist, Monk.
- Inspiring Quests: Trojan Inspiring Quest.
- The Main Quest in Spheres is documented separately.

The three Trials are not generic kill quests:
- Chi Canyon: three monster tiers, 100/200/300 points, 180 seconds.
- Battle Dojo: activate array, summon masters, up to four challenges, 180 seconds per round.
- Rune Mountain: four waves of Bushfire Beasts, then Lich Kings and Yellow Rune Essences.

These mechanics require timed/scored/wave activity support, not the existing single-counter prototype.

## 6. Source-code retrieval and compatibility rule

No public source code for the Conquer Online Mobile quest implementation has been established by this research. The community development wiki describes older/classic Conquer formats and packet structures (including task/dialog/status message families); it does not establish that those definitions apply to the current Android Mobile client. Do not label classic source, leaked code, PC quest scripts, private-server scripts or reverse-engineered PC DAT layouts as Mobile code.

If a Mobile client resource archive or a legally accessible source package is provided/located, inspect its version, hashes, format and provenance first. Decode only demonstrably relevant quest/NPC/map/item resources. Preserve raw extracts and record the exact client build. Compare extracted behavior against official Mobile guides and observed Mobile client behavior before translating any logic into Godot.


## 6A. External technical references discovered (not Mobile-certified)

The research pass now includes technical material outside the official Mobile guide:

1. **Conquer Online Development Wiki** — public community documentation for older/classic Conquer clients. It indexes task-related message families such as MsgTaskStatus, MsgTaskDetailInfo and MsgTaskDialog, alongside NPC/dialogue messages and legacy client data formats:
   - https://conquer-online.github.io/wiki/network/messages/
   - https://conquer-online.github.io/wiki/files/formats/dat.html
   - Reliability policy on the wiki distinguishes unverified, observed and reverse-engineered claims. Its scope is not the current Android Mobile client.
2. **ZfProtocol5066** — an explicitly versioned protocol document for Conquer Online 2.0 English client v5066. It describes classic MsgNpc/MsgDialog structures; it is useful for understanding legacy dialogue flow, not proof of Mobile wire compatibility:
   - https://github.com/conquer-online/cops-protocols-doc/blob/main/ZfProtocol5066.md
3. **LongV6270 open-source server implementation** — source files provide concrete examples of task-status add/remove/update processing, task-detail state fields, and task-dialog option/answer routing:
   - https://github.com/darkfoxdeveloper/LongV6270/blob/main/src/modules/Long.Module.TaskDetail/Network/MsgTaskStatus.cs
   - https://github.com/darkfoxdeveloper/LongV6270/blob/main/src/modules/Long.Module.TaskDetail/Network/MsgTaskDetailInfo.cs
   - https://github.com/darkfoxdeveloper/LongV6270/blob/main/src/Long.Kernel/Network/Game/Packets/MsgTaskDialog.cs
   This is an independently authored server implementation, not TQ's original Mobile source. Its implementation choices and enum values must be checked against the target Mobile build before adoption.
4. **Cooldown developer discussion on NPC/task database behavior** — a 2025 thread discusses cq_npc/cq_dynanpc task slots, cq_action execution, task-driven NPC dialogs and task-to-action chaining:
   - https://cooldown.dev/topic/410-looking-for-help-with-tq-binary-database-npc-actions/
   This is community technical discussion and an implementation lead, not authoritative Mobile documentation. Statements about database access/version-specific server behavior remain unverified until corroborated.
5. **Mobile event guides outside the main Quests index** — independent event pages expose additional time-limited activity structures. Five historical examples have been added to the research catalogue: Love Cycles, Forbidden Area, Frostland Park, Into Wilds and Trial of Legends. They remain inactive historical research records; their dates, eligibility, NPCs, maps and mechanics are source-backed, while missing IDs/branches/targets are explicitly unresolved.

### How these references may be used

- Reuse the conceptual separation between task status, task detail, dialogue presentation, NPC activation, action dispatch and persistent per-character task state when designing our own engine.
- Treat open-source server code as a comparative implementation sample, not as original client code or a Mobile source dump.
- Treat protocol layouts and legacy DAT formats as version-scoped. Do not import packet IDs, field widths, enums, table schemas or binary decoders into the Godot project without target-build corroboration.
- Treat cq_action/cq_npc/Lua concepts as a possible legacy quest-authoring model. Do not assume Mobile uses those same tables or scripts.
- Preserve original source links, version labels, evidence grades and unresolved fields for every extracted mechanic.

## 7. Admission gate

A record may move from research to implementation only when:
1. Mobile-specific source evidence exists;
2. ordered steps and branches are known, or the official activity mechanics are fully specified;
3. all gameplay-critical IDs resolve to verified registries;
4. NPC/map/target identity and coordinates are cross-validated against the correct Mobile world;
5. eligibility, reset, timing, attempts, rewards and claim semantics are known;
6. UI flow is mapped;
7. tests cover success, failure, retry, abandon, save/resume, duplicate reward prevention and invalid target rejection.

Until then: catalogue it, research it, do not activate it.
