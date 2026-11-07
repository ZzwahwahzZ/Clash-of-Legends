# Quest System — External Evidence Register
**Research date:** 2026-11-07  
**Target baseline:** Owner-pinned Android client `com.Tq.CQ2ClientAndroid`, versionName `1.1.2.3`, versionCode `123` (see `CANONICAL_CONQUER_MOBILE_REFERENCE_LOCK.md`).  
**Purpose:** Record externally verifiable Conquer Online Mobile quest-system evidence to guide source comparison. This is corroborating research, **not** proof that every page exactly matches the pinned APK's server-side content revision.

## Evidence classification
- **Official mobile guide:** first-party published Conquer Online Mobile content. Strong evidence that the described feature existed in the mobile game, but individual pages are dated 2023 and are not independently tied to the pinned 2026 APK build.
- **Pinned client evidence:** files/screens/behavior extracted from the owner-supplied Android 1.1.2.3 snapshot. Must be separately recorded with hashes and offsets.
- **Other-client/community documentation:** comparison leads only; never silently promoted to mobile-canonical facts.

## Confirmed official mobile quest families and mechanics

### Daily — Bounty Hall
Official guide: https://comobile.99.com/guide/info/quests/2023-01-31/daily_-_bounty_hall.shtml
- Long-term activity; Level 80+; entry via Bounty Hall button or Chinju in Twin City (443,293).
- Three randomly available quests per day, selected from Easy/Normal/Hard/Expert tiers.
- The player must complete or give up the current set before taking/refeshing another set; next quests appear after completing the current ones.
- Daily accumulation is described as six added per day, capped at 18 stored quests.
- Published objective families: message delivery, material collection, monster kills/hunts, and item submission; Trojan-only Weapon Spirit variants additionally include boss hunting.
- A Go button beside the quest provides pathfinding.
- The guide describes Gold-independent original rewards (EXP items/materials/active points and, in its original online economy, CP refreshes). For this project, paid CP refreshes are out of scope; any adapted refresh/reward rules must follow the owner's Gold-only/offline invariants.

### Daily — Farmland Defence
Official guide: https://comobile.99.com/guide/info/quests/2023-01-31/daily_-_farmland_defence.shtml
- Long-term; Level 50; Roberts in Twin City (349,342).
- One 60-second pest-elimination session per day.
- Three pest types have distinct score/stun behavior: Evil Locust (3 points), Evil Aphid (1 point), Evil Bee (0 points and 3-second stun).
- Score and daily ranking/reward loop are part of the published activity.
- This is a timed activity/quest-like system, not a conventional fetch/kill quest; preserve its separate rules if confirmed in the pinned client.

### Daily — Hunting Battle
Official guide: https://comobile.99.com/guide/info/quests/2023-01-31/daily_-_hunting_battle.shtml
- Long-term; Level 130+; entered through the Hunting Battle button.
- Four published daily time windows; participation limit two rounds per day.
- Three sequential islands use point thresholds and automatic transitions; stage rewards are claimable once per day.
- Normal, elite, boss and hero kills award different points.
- This is a timed multi-stage hunting activity with entry, round limits, score, transitions, claims and ranking. Do not reduce it to a generic kill counter.

### Daily — Mayhem Land Crusade
Official guide: https://comobile.99.com/guide/info/quests/2023-01-31/daily_-_mayhem_land_crusade.shtml
- Daily availability window; Level 40 of second rebirth; Splinter in Twin City (392,324).
- Five forces; each progresses through three kill-point phases (200/500/1000); full phases permit summoning chiefs; chiefs raise the Mayhem Lord phase.
- A scheduled boss summon, feat points, pack claims and ranking rewards are described.
- This is a staged event/quest loop with timed boss behavior and claim thresholds.

### Epic Quest — Ninja
Official guide: https://comobile.99.com/guide/info/quests/2023-02-16/quest_-_ninja_epic_quest.shtml
- Requirement: Level 70+ second rebirth; Wind Sage in Twin City (388,316); subsequent NPCs/areas include Divine Shadow and Swapper Starry in Infinite Abyss.
- Three sequential trials depend on quest items (YinYang Seal, Elemental Jade, Life's Eye); failure sends the player back to an earlier stage.
- Stardust is an alternate failure output/exchange resource; scrolls can unlock named skills.
- This is a multi-map, item-gated, probabilistic progression chain with retry/failure branches and class-specific reward/skill unlocks.

### Epic Quest — Taoist
Official guide: https://comobile.99.com/guide/info/quests/2023-02-16/quest_-_taoist_epic_quest.shtml
- Requirement: Level 70+ second rebirth; starts with Taoist Moon in Twin City (381,318), then moves to Taoist Temple NPCs/ovens.
- Three-stage item transformation chain: Red/White Flowers → Treasure Leaf → Star Crystal → Divine Panacea, with retry loops after failures.
- Alternative Yin Yang Fish rewards and class-specific scroll/skill outcomes are described.
- This is a multi-map crafting/quest chain, not merely a talk/collect/kill sequence.

### Inspiring Quest — Trojan
Official guide: https://comobile.99.com/guide/info/quests/2023-02-16/inspiring_quests_-_trojan_inspiring_quest.shtml
- Requirement: Level 45+; Aeneas in Twin City (441,379); entry through the Inspiration Guide button.
- Completion unlocks the Inspiration function and publishes Trojan-specific rewards.
- This is a UI-entry-point plus NPC-guided unlock, and must be tracked separately from ordinary NPC-only quests.


### Epic Quest — Monk
Official guide: https://comobile.99.com/guide/info/quests/2023-02-16/quests_-_monk_epic_quest.shtml
- Requirement: Level 70+ second rebirth; Head Abbot in Twin City (383,315) leads to Western Paradise, with later NPCs across Western Paradise and Oriental Fairyland.
- Three sequential item-submission trials: Red/White Flowers → Spiritual Gem → Buddha's Necklace → Boundless Heart. Failure returns the player to the preceding stage.
- Rosewood Incense is an alternate failure output and can be exchanged with White Dragon in Oriental Fairyland; the final item transforms the Monk's weapon and unlock scrolls teach class-specific skills.
- This is another distinct class-gated, multi-map, retryable progression chain.

### Time-limited event quest examples (external mobile corroboration; not guaranteed active in the pinned snapshot)
- **Twinkling Fest (Feb. 2026):** https://comobile.99.com/guide/2026-02-05/join_the_twinkling_fest_and_start_an_amazing_adventure.shtml — Level 80 gate, event NPC in Twin City, travel to Snowland, shard collection, event quest chain and rewards.
- **Love Cycles (Sept. 2026):** https://comobile.99.com/guide/2026-09-03/love_cycles_is_now_live_from_sept__8th_to_sept__21st_.shtml — Level 80 gate, event NPC in Twin City, seven daily-unlocking Beast Lineage Awakening quests, daily activity threshold, repeatable bridge-repair rounds, staged rewards and point accumulation.
- These current-year guides demonstrate that event quest structures continue to evolve beyond the 2023 evergreen guide. They are evidence of mobile event patterns, not evidence that expired events should be active in the offline build or that their online ranking/CP mechanics should be copied.

## What this evidence changes in the implementation plan
1. The quest engine cannot be limited to a linear chain of kill/collect/talk/level objectives. The official mobile material establishes distinct daily activity modes, timed rounds, scoring, stage thresholds, claim limits, item transformation chains, failure/retry branches, class gates, unlocks and cross-map hand-offs.
2. The quest catalogue must support typed activity definitions and objective handlers, not just one generic counter. Candidate handler families to validate against the APK include: NPC message delivery; location material collection; inventory item submission; kill/hunt counters; timed survival/defence scoring; scheduled multi-round hunting; phase/threshold progression; boss summon/kill; item transformation/consumption; skill unlock; and UI/button-triggered unlock.
3. Cross-map references are explicit in the official mobile examples: Twin City ↔ Infinite Abyss and Twin City ↔ Taoist Temple. The runtime data model must therefore use stable map/NPC/item/monster IDs and portal/navigation links rather than hard-coded single-city coordinates.
4. Timed resets, daily caps, stored quest capacity, claim idempotency, failure/retry state and save/reload need separate acceptance tests. Offline adaptation must define a deterministic local clock/reset policy while retaining the gameplay purpose; it must not reproduce server rankings or paid CP paths as network features.
5. These pages are external corroboration only. Before any entry is marked canonical for Android 1.1.2.3, compare it with the pinned APK/resources and capture exact in-client UI/state evidence. Other-client documentation is not sufficient.

## Remaining source-verification blockers
- Validate the Android 1.1.2.3 reader/schema for `questinfo.dat` and `taskitem_info.dat`; the current candidate decryptions remain unapproved.
- Extract exact NPC, map, monster, item, skill and reward IDs and cross-reference them against the same pinned snapshot.
- Inventory all quest families and all quest records; the official pages above are examples, not an exhaustive quest list.
- Capture quest UI, NPC/player speech bubbles, objective tracker, quest journal, reward preview and claim states from the pinned mobile client.
- Confirm which 2023 guide entries remain present/unchanged in the pinned client and identify server-side/region-specific differences.
- Review licenses/permissions separately. Public guide visibility does not grant permission to redistribute proprietary game assets, text, client code or UI artwork.

## References
- Official Conquer Online Mobile guide index: https://comobile.99.com/guide/info/info.shtml
- Bounty Hall: https://comobile.99.com/guide/info/quests/2023-01-31/daily_-_bounty_hall.shtml
- Farmland Defence: https://comobile.99.com/guide/info/quests/2023-01-31/daily_-_farmland_defence.shtml
- Hunting Battle: https://comobile.99.com/guide/info/quests/2023-01-31/daily_-_hunting_battle.shtml
- Mayhem Land Crusade: https://comobile.99.com/guide/info/quests/2023-01-31/daily_-_mayhem_land_crusade.shtml
- Ninja Epic Quest: https://comobile.99.com/guide/info/quests/2023-02-16/quest_-_ninja_epic_quest.shtml
- Taoist Epic Quest: https://comobile.99.com/guide/info/quests/2023-02-16/quest_-_taoist_epic_quest.shtml
- Trojan Inspiring Quest: https://comobile.99.com/guide/info/quests/2023-02-16/inspiring_quests_-_trojan_inspiring_quest.shtml
- DAT format documentation (legacy PC patch documentation; comparison only): https://conquer-online.github.io/wiki/files/formats/dat.html


## Expanded catalogue research (2026-11-07)

A deeper pass has been committed to `docs/quests/QUEST_CATALOGUE_RESEARCH_AND_RUNTIME_SCHEMA.md`. It adds:
- Main Quest in Spheres level bands (1–50, 50–75, 75–130, 1st Rebirth 1–60 and 60–130, 2nd Rebirth 1–140 and 140+), including the official named guidance NPCs and unlock milestones.
- The full published objective families and tier/stacking/Go-pathfinding mechanics of Bounty Hall.
- Expanded exact published rules for Farmland Defence, Hunting Battle and Mayhem Land Crusade.
- Full published item/actor/stage/failure-retry chains for Ninja, Taoist and Monk Epic Quests.
- New Evil Labyrinth, Beast Scramble/Realm Quests, Sea Treasure Hunt, Twinkling Fest, Love Cycles, Into Wilds, New Server Bash and New Server Carnival as separate event/activity evidence.
- A normalized data contract and typed objective-handler requirements, explicitly marked as our integration schema rather than the original Mobile file format.

Important distinction: the official Mobile guide index itself currently enumerates four Daily Quests, three Epic Quests and one Inspiring Quest, while the Main Quest in Spheres and many event/activity guides are separate pages. This is a verified published-guide index, **not proof that the full in-game quest catalogue contains only these entries**. The external inventory remains incomplete and must continue across dated event pages, tutorial/zone/rebirth/sub-class/house/equipment quests and the pinned APK's own data.

### Technical research correction
The legacy PC DAT and TQ cipher documentation is useful only to understand possible file-format families. It does not validate the Android 1.1.2.3 reader, cipher or quest schema. Existing candidate `questinfo.dat` / `taskitem_info.dat` decodes remain unapproved. Do not use candidate counts as runtime quest totals.

### Newly added official Mobile references
- Main Quest in Spheres: https://comobile.99.com/guide/2024-03-19/main_quest_in_spheres.shtml
- New Evil Labyrinth: https://comobile.99.com/guide/2023-08-29/new_evil_labyrinth.shtml
- Beast Scramble: https://comobile.99.com/guide/2023-08-03/beast_scramble_-_unite_for_the_realm_and_compete_to_be_the_strongest_.shtml
- Sea Treasure Hunt: https://comobile.99.com/guide/2024-07-26/sea_treasure_hunt.shtml
- Twinkling Fest: https://comobile.99.com/guide/2026-02-05/join_the_twinkling_fest_and_start_an_amazing_adventure.shtml
- Love Cycles: https://comobile.99.com/guide/2026-09-03/love_cycles_is_now_live_from_sept__8th_to_sept__21st_.shtml
- Into Wilds: https://comobile.99.com/guide/2026-09-24/join_into_wilds_now_for_generous_rewards_from_sept__29th_to_oct__12th_.shtml
- New Server Bash: https://comobile.99.com/guide/info/quests/2024-01-05/new_server_-_new_server_bash.shtml
- New Server Carnival: https://comobile.99.com/guide/info/quests/2024-03-25/new%20server%20spheres%20carnival.shtml
