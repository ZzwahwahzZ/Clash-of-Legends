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


### A.1 File-cipher and Android reverse-engineering references

| Source | Technical detail | Evidence scope | Project use / restriction |
|---|---|---|---|
| [Conquer Online Development Wiki — TQ File Cipher](https://conquer-online.github.io/wiki/security/tqfile.html) | Documents a 128-byte key generated by the Microsoft-style LCG, then per-byte XOR and right-rotation; the seed is specified per file in the DAT index | Community reverse-engineering reference for legacy Conquer clients. The page explicitly warns that this cipher applies only to files marked with this cipher; other files use different methods | Use as a testable algorithm candidate only. A Mobile DAT entry, seed, and successful structural/text validation are required before applying it to any Mobile file |
| [Conquer Online Development Wiki — DAT format index](https://conquer-online.github.io/wiki/files/formats/dat.html) | Distinguishes plain text, binary-encoded, TQ File Cipher, RSA-encrypted, SWF and custom-encrypted DAT files | The published inventory is specifically labelled Patch 5517, not ConquerOnline-1.1.2.3 Mobile | Confirms that a `.dat` extension does not identify its encoding. Do not copy Patch 5517 file names, seeds or encryption labels into the Mobile corpus |
| [Conquer Online Development Wiki — Messages directory](https://conquer-online.github.io/wiki/network/messages/index.html) | Lists legacy message families including MsgTaskStatus (1134), MsgTaskDetailInfo (1135), MsgTaskDialog (2032), and MsgNpc (2031) | Community-maintained protocol directory spanning legacy patches; it is not a Mobile packet specification | Use the names as reverse-engineering search terms in DEX/native code. Do not implement packet IDs or field layouts without Mobile-client evidence |
| [Androguard 4.1.4 documentation — AnalyzeAPK](https://androguard.github.io/androguard/reference/androguard/misc.html) and [Analysis/XREF API](https://androguard.github.io/androguard/reference/androguard/core/analysis/analysis.html) | Documents APK + DEX analysis and string-to-method cross-reference extraction | Tool documentation, not a Conquer game-data specification | Supports the current read-only APK analysis pipeline. The actual extracted class names, strings and XREFs must still be reported from the four exact Mobile APK components |

**Required validation rule for any cipher candidate:** retain the original file hash; establish the exact Mobile file path and archive/APK origin; locate a Mobile-specific seed or decryption call in the matching client build; test the transform on a copy; then validate the output against independent structure indicators (headers, record boundaries, field counts, encoding and/or known client strings). A readable fragment by itself is not proof that the cipher, seed, or schema is correct.

**Important distinction:** the current source bundle is identified as `ConquerOnline-1.1.2.3` Mobile. The legacy wiki's Patch 5517 examples are not interchangeable with that build. The audit scripts therefore keep the 9527/1234 probes marked research-only and do not promote them to Mobile decryption settings.

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


## C. Direct Mobile quest catalogue evidence — base APK, build 1.1.2.3

The Run 57 artifact contains an Apktool-decoded copy of the exact base APK resource:
`assets/ConquerRes/ini/questinfo.ini`, with parallel locale files under `ini_ar/` and `ini_sp/`. This is direct client data, not a PC guide or a web-derived quest list.

### C.1 Structural counts (catalogue records, not verified playable quest count)

| Locale | Declared total | Numeric sections | Unique MissionId values | Duplicate-ID collisions |
|---|---:|---:|---:|---:|
| English | 2,510 | 2,510 | 2,509 | 1 |
| Arabic | 2,480 | 2,480 | 2,479 | 1 |
| Spanish | 2,531 | 2,531 | 2,456 | 75 |

Source SHA-256:
- English: `adb61b7175830e1b3ec29cce413f71cdedbbcb24f2fcdec36496291c2dd539b1`
- Arabic: `d60c1e2e982012b099b1ba3877084b89b0046ef869d716fc4b7a555b49f39c07`
- Spanish: `d96af837d64e6cb5b34ac0960eb28df9ddea13a141b471a65d13bc5b6dfac203`

English category distribution by `TypeId`: Main Quests 505; Important Quests 71; Daily Quests 869; Adventure 797; Class Quests 18; Festival (TypeId 8) 155; Festival (TypeId 9) 93; unlabelled TypeId 99: 2. The header defines 11 TypeIds, but Types 4, 7, 10 and 11 have no English records in this file. Arabic and Spanish record counts differ and must not be silently padded or merged.

### C.2 Fields and what the file actually establishes

Every English record has `MissionId`, `Name`, `TypeId`, `Prequest`, `Map`, `IntentAmount`, `Content` and `Prize` keys; values may still be empty. `BeginNpcId` exists in 2,476 records and `FinishNpcId` in 2,475. `Intention1` is present in 2,506 records; later intention fields are progressively sparse (Intention2: 187; Intention3: 91; Intention4: 32; Intention5: 9; Intention6: 5; Intention7: 4; Intention8–10: 2 each). `Prize` has a non-empty value in 673 records and `IntentionDesp` in 812. `AutoLuaCmd` occurs in 388 records.

The English `Map` field is `0` in 2,469 records, `1002` in 40, and `1036` in 1. Therefore Map=0 is not a usable destination and must not be interpreted as Twin City or as a valid route. NPC endpoint strings are composite values (for example, ID/map/coordinates/name/region fields); parse them only after their component order and coordinate semantics are independently validated.

### C.3 Data-integrity findings

- English and Arabic each contain one repeated MissionId: `3938`, appearing in numeric sections 357 and 473 (both titled “Conquest of Nether” in English). Preserve both source rows until client selection semantics are known.
- Spanish has 75 additional duplicate-ID collisions, mostly festival records repeated at separate section positions. It also has a distinct MissionId set from English and Arabic.
- English vs Arabic: 2,473 shared IDs; 36 English-only and 6 Arabic-only.
- English vs Spanish: 2,449 shared IDs; 60 English-only and 7 Spanish-only.
- The same TypeId labels are not semantically stable across locales: for example, English TypeId 4 is “Equipment Bonus” while Arabic TypeId 4 is labelled “عيد الأضحى”; English TypeId 6 is “Class Quests” while Arabic labels it “عداء”. Treat this as a localization/data-version defect candidate, not as permission to rewrite the client taxonomy.

### C.4 Admission gate

This INI is now a high-value source for the quest catalogue and gives direct evidence for IDs, names, type IDs, level bounds, prerequisite expressions, endpoint declarations, objective text, and some reward strings. It does **not** by itself establish that every row is a currently playable quest, how the client evaluates every field, the full NPC dialogue tree, the meaning of every composite NPC field, or the runtime effects of Lua commands.

No runtime quest definitions are approved from this file alone. Keep all rows research-only until:
1. the base APK and all three split APK components have been audited;
2. duplicate and cross-locale mismatches have been resolved against client behavior;
3. encrypted `luacfg/questinfo.dat`, `taskitem_info.dat`, NPC dialogue tables and task scripts have been decoded with a Mobile-specific verified method;
4. NPC/map IDs and coordinates have been cross-checked against the same build's map and NPC source tables;
5. objectives, state transitions and rewards have been corroborated against client code/data.

The repeatable aggregate parser is `tools/gameplay_source_audit/parse_questinfo_catalogues.py`. It emits hashes, structural counts, field-presence counts and locale ID-set differences only; it does not commit the quest text or full proprietary records.
