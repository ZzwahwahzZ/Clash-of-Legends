# External Quest and Technical Reference Audit

Status: research evidence only; no external legacy task scripts or packet layouts are approved for direct runtime use in the Mobile target.

## A. Legacy protocol and engine references

| Source | What it contains | Scope / trust boundary | Project use |
|---|---|---|---|
| [Conquer Online Development Wiki — Messages](https://conquer-online.github.io/wiki/network/messages/) | Message directory including MsgTaskStatus (1134), MsgTaskDetailInfo (1135), MsgTaskDialog (2032), MsgNpc (2031), and other client/server message families | Public community documentation for older/classic Conquer clients; individual articles may have different evidence grades | Compare responsibilities and data-flow boundaries; do not assume Mobile packet compatibility |
| [Conquer Online Development Wiki — DAT formats](https://conquer-online.github.io/wiki/files/formats/dat.html) | Legacy client DAT format families, encryption notes and patch-scoped file inventory | Patch-scoped classic client documentation; not a Mobile archive inventory | Search vocabulary only; never assume the Android client contains these exact files |
| [ZfProtocol5066](https://github.com/conquer-online/cops-protocols-doc/blob/main/ZfProtocol5066.md) | Explicit protocol description for Conquer Online 2.0 English client v5066, including MsgNpc and MsgDialog | Versioned legacy PC protocol, not Mobile | Technical comparison for dialogue and NPC interaction semantics |
| [LongV6270 MsgTaskStatus](https://github.com/darkfoxdeveloper/LongV6270/blob/main/src/modules/Long.Module.TaskDetail/Network/MsgTaskStatus.cs) | Task list status, add/remove/update modes, per-task identity/status/time, DB-backed completion lookup | Open-source server emulator implementation; not original TQ source and not Mobile-certified | Comparative sample for state synchronization and persistence boundaries |
| [LongV6270 MsgTaskDetailInfo](https://github.com/darkfoxdeveloper/LongV6270/blob/main/src/modules/Long.Module.TaskDetail/Network/MsgTaskDetailInfo.cs) | Seven task data slots read from task-detail storage and returned to client | Same emulator/version caveat | Comparative sample for objective/task-specific state payloads |
| [LongV6270 MsgTaskDialog](https://github.com/darkfoxdeveloper/LongV6270/blob/main/src/Long.Kernel/Network/Game/Packets/MsgTaskDialog.cs) | Dialogue interaction types, answer selection, task/action dispatch, Lua-script branch | Same emulator/version caveat | Comparative sample for branching dialogue/action dispatch |

| [COPS v6 Emulator — Data/Tasks](https://gitlab.com/conquer-online/servers/cops-v6-emulator-enhanced-edition/-/tree/master/Data/Tasks) | Public Lua NPC/task script samples; the emulator project describes its scripting engine as covering NPCs, monster-death hooks, items, events and traps, based on cq_action/cq_task | Explicitly a legacy Conquer emulator, with the published Lua dumps described by its maintainer as incomplete; not Mobile source | Extract task graph patterns and compare NPC/action semantics only |
| [COPS v6 Emulator project description](https://gitlab.com/conquer-online/servers/cops-v6-emulator-enhanced-edition/-/tree/master) | Documents MySQL-backed database, Lua scripting engine and task/action table compatibility goals | Emulator implementation; its own notes describe a COPS v7-derived database layout and legacy TQ table ancestry | Useful engineering reference for data-driven quest authoring; not proof of Mobile schema |
| [Cooldown — Any quests database/wiki around?](https://cooldown.dev/profile/185-cptsky/content/?type=forums_topic_post) | Experienced community contributor says there is little complete public quest documentation; points to leaked TQ databases and an incomplete public set of Lua NPC dumps | Community assessment, not a formal inventory; no use of leaked proprietary data is authorized or required | Sets realistic expectations: public samples can clarify architecture, but a complete authoritative quest corpus may not be publicly available |
| [Cooldown — NPC binary database actions discussion](https://cooldown.dev/topic/410-looking-for-help-with-tq-binary-database-npc-actions/) | Developer discussion of cq_npc/cq_dynanpc task slots, cq_action, NPC activation, dialogue replies and task-to-action routing | Community discussion; page currently blocks automated full-page retrieval; individual claims need independent corroboration | Search lead for legacy task authoring and data relationships only |

### Confirmed boundaries

- The ZfProtocol document itself identifies its scope as Conquer Online 2.0 English client v5066.
- LongV6270's source is a server implementation, not a source release from TQ and not a verified Android Mobile client implementation.
- The Cooldown thread is a useful technical lead but is not sufficient evidence that the current Mobile client uses the same server tables or Lua task model.
- The community wiki's message names and file formats must remain version-scoped.

## B. Additional Mobile task/activity material discovered outside the main Quests index

These are official Mobile event-guide pages, distinct from the permanent Quests navigation. All dates below are historical and expired as of 2026-11-07; they are catalogued for mechanics coverage, not activated.

| Activity | Published window | Mobile-specific evidence found | Remaining unknowns |
|---|---|---|---|
| [Love Cycles](https://comobile.99.com/guide/2026-09-03/love_cycles_is_now_live_from_sept__8th_to_sept__21st_.shtml) | Sep 8–21, 2026 | Seven daily Beast Lineage Awakening quests; Suyi at Twin City (455,366); daily Active Points claim; Magpie Bridge reward cycle and ranking | Exact seven quest chains, dialogues, IDs, state transitions |
| [Forbidden Area](https://comobile.99.com/guide/2026-09-11/passing_the_forbidden_area_to_win_inner_power_books_from_sept__15th_to_sept__28th.shtml) | Sep 15–28, 2026 | Prof. Allen at Twin City (452,365); timed Forbidden Maze, Forbidden Tricks and Forbidden Pond challenges | Exact map/portal IDs, timers, monster IDs, entry/retry state |
| [Frostland Park](https://comobile.99.com/guide/2026-10-16/take_challenges_to_compete_for_high_ranking_and_huge_prizes_in_the_frostland_park.shtml) | Oct 20–Nov 2, 2026 | Guild registration; Apollo boss, Wishing Pool occupation, Vermins, Dragonflies; 20-minute scoring and guild/hero rankings | Spawn IDs, event state machine, ranking persistence and reward transaction IDs |
| [Into Wilds](https://comobile.99.com/guide/2026-09-24/join_into_wilds_now_for_generous_rewards_from_sept__29th_to_oct__12th_.shtml) | Sep 29–Oct 12, 2026 | Eloise at Wind Plain (453,379); exploration stamina/manuals, success/failure progression, area rewards and daily/cumulative rankings | Exact area map IDs, random algorithm, stamina costs, reward probabilities |
| [Trial of Legends](https://comobile.99.com/guide/2026-03-20/defeat_devils_to_get_combat_badges_in_exchange_for_rewards_from_apr__14th_to_apr__27th.shtml) | Apr 14–27, 2026 | Lady East at Twin City (467,367); scheduled bosses at two Twin City sites and Wind Plain; Combat Badge exchange | Boss IDs, per-player limits, drop quantities and exact exchange state |

## C. Implications for the quest catalogue

1. The main Mobile Quests index is not exhaustive for all event missions and activities.
2. Historical event content must be represented with start/end dates and inactive-by-default lifecycle state.
3. A guide may expose the overall activity loop while omitting exact quest IDs, dialogue text, NPC action IDs, monster IDs or internal task state. Such content remains research-only.
4. Mobile-specific guide evidence can establish that an activity exists and describe its published mechanics. It does not establish the hidden implementation or protocol.
5. The project's Gold-only economy rule must be applied explicitly: CP-only purchases or CP-based shortcuts from source events cannot be silently recreated or replaced with invented Gold costs.

## D. Next research targets

- Continue crawling the Mobile site's Event Guide and Update archives across multiple years, following internal links from each activity guide.
- Search independent Mobile community walkthroughs, screenshots and videos for exact step order, dialogue options, target names and missing branches.
- Search only legally accessible client resources and public source packages; verify package identity, version/build, hashes and provenance before decoding.
- Compare any recovered Mobile evidence with the same activity in current Mobile guides and observed client behavior.
- Keep PC/classic sources as corroborating technical analogues unless the Mobile build itself confirms compatibility.
