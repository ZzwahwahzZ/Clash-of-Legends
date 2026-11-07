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
