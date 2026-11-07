# Conquer Online Mobile — Quest Catalogue Research & Runtime Data Contract

**Research date:** 2026-11-07  
**Pinned comparison target:** `com.Tq.CQ2ClientAndroid`, versionName `1.1.2.3`, versionCode `123`.  
**Status:** External catalogue expanded; source-to-pinned-client verification and runtime admission remain blocked pending APK reader/schema validation.

## 1. Research rules

This catalogue separates four evidence classes:

- **MOBILE_OFFICIAL:** first-party Conquer Online Mobile guide. It proves the documented feature/mechanics existed in Mobile at the guide's publication revision, not necessarily that every detail is unchanged in APK 1.1.2.3.
- **MOBILE_CLIENT_VERIFIED:** directly decoded or observed in the owner-pinned Mobile APK, with source hash, offset/key and repeatable evidence. No external guide alone receives this status.
- **OTHER_CLIENT_COMPARISON:** PC/legacy Conquer documentation and reverse-engineering references. Useful for locating concepts or learning general data patterns only; never imported as Mobile truth.
- **UNRESOLVED:** missing identifiers, exact branch/dialogue content, coordinates, map IDs, target placement or schema.

No quest ID, NPC ID, map ID, monster ID, item ID, dialogue branch or coordinate may be fabricated from a translated name. Human-readable coordinates from guides are retained as source notes and are not runtime navigation anchors until map identity, coordinate space and scene placement are cross-validated.

## 2. Mobile-official quest families found

### 2.1 Main storyline — Main Quest in Spheres

Source: https://comobile.99.com/guide/2024-03-19/main_quest_in_spheres.shtml  
Status: MOBILE_OFFICIAL / storyline outline; individual step script and dialogue branches not published in this guide.

- Participant: all players; long-term.
- Main guidance NPCs: Eloise, Twin City (441,379); Dunn Burg, Twin City (383,346).
- Newcomer, Level 1–50: Eloise introduces the hero to NPCs including Song Qing, Song Shiyu, Lieutenant Chen, Li Kui and Li Gui; equipment upgrade/composition learning and first mount are part of the journey.
- Stepping Stone, Level 50–75: Wind Plain and Maple Forest storyline; bandit-group context; gem and sub-class unlocks; Twilight Towers unlock.
- Reaching Delight, Level 75–130: return to Twin City, meet Den Berg with Eloise's recommendation; Spheres story; rebirth and lineage unlocks, Deathtrap and equipment bonus systems.
- Stable Progress, 1st Rebirth Levels 1–60: Eloise/Den Berg, Half Facet and Enigma Domains; Ether Spirit, Ethersuit, Ethercore, Mine Contest and Cyclical Trial unlocks.
- Scaling New Heights, 1st Rebirth Levels 60–130: second-rebirth class, Perfection, Chi and Soul; Mayhem Land and Evil Labyrinth.
- Ultimate Achievement, 2nd Rebirth Levels 1–140: Jiang Hu, Rune, Inner Power and related activities.
- Peak of Glory, 2nd Rebirth 140+: story continuation is announced but not detailed.

**Not yet available from this guide:** exact ordered subtask IDs, full NPC dialogue/choices, monster/item requirements, failure states, reward quantities and exact transition triggers. Do not convert this outline into invented micro-quests.

### 2.2 Daily — Bounty Hall

Source: https://comobile.99.com/guide/info/quests/2023-01-31/daily_-_bounty_hall.shtml  
Status: MOBILE_OFFICIAL.

- Level 80+; entry button or Chinju at Twin City (443,293).
- Three random quests offered daily across Easy/Normal/Hard/Expert tiers.
- Existing set must be completed or abandoned before taking another set or refreshing; new set appears after completion.
- Six quests added per day; stored capacity 18.
- Objective families explicitly documented: message delivery, material collection from a required place, kill required monsters, submit items collected from required monsters, hunt monsters in the wild.
- Trojan-only Weapon Spirit branch after Trojan Inspiring Quest and Weapon Spirit unlock: item submission, item collection, monster hunting and boss hunting.
- Published tier rewards: Easy = Mystic EXP Ball (B), Floral Essence (B), 2 Meteor Scrolls (B); Normal = Mystic EXP Ball (B), Floral Essence (B), Leopard Chi Liquor (B) x5; Hard = Mystic EXP Ball (B), +2 Stone (B), Bright Star Stone; Expert = Mystic EXP Ball (B), Floral Essence (B) x2, Dragon Ball (B). Trojan-only rewards vary by tier and include Martyr Rings / Spirited Lottery Scraps.
- Six Bounty Hall quests count toward 60 Active Points in the guide revision. The page also notes Fellow Fighters and Magnolias All Around were removed from that daily activity set.
- Guide says Go beside the quest triggers pathfinding.

**Project adaptation constraint:** CP refresh is excluded by the project's Gold-only/no-premium rule. Do not silently replace the published rewards or tier rules; adaptation decisions must be explicit and documented separately.

### 2.3 Daily — Farmland Defence

Source: https://comobile.99.com/guide/info/quests/2023-01-31/daily_-_farmland_defence.shtml  
Status: MOBILE_OFFICIAL.

- Level 50; Roberts, Twin City (349,342).
- One pest-elimination session per day, lasting 60 seconds.
- Evil Locust = 3 points; Evil Aphid = 1 point; Evil Bee = 0 points and stuns the player for 3 seconds.
- Point rewards include Wondrous EXP Ball (B), Study Points, Dragon Ball and Meteors.
- Daily top five receive Dragon Balls (B), delivered to mailbox at 00:00 next day.

This is a timed scoring activity, not a generic kill quest.

### 2.4 Daily — Hunting Battle

Source: https://comobile.99.com/guide/info/quests/2023-01-31/daily_-_hunting_battle.shtml  
Status: MOBILE_OFFICIAL.

- Level 130+; Hunting Battle entry button.
- Four daily windows listed: 13:00, 16:00, 19:00 and 22:00, each 15 minutes; two rounds per day.
- Forthy Ground has three islands. Start on Island 1; 100 points advances to Island 2 and consumes those points; 200 points advances to Island 3 and consumes those points.
- Stage rewards are claimable once daily at 100/200/300 total points.
- Normal monster = 1 point; elite = 5; boss = 50 (boss spawns at minutes 1, 6 and 11); hero = 10 plus 20% of target's points.

This needs timed session, score, island-transition and claim-state handlers, not a kill counter.

### 2.5 Daily — Mayhem Land Crusade

Source: https://comobile.99.com/guide/info/quests/2023-01-31/daily_-_mayhem_land_crusade.shtml  
Status: MOBILE_OFFICIAL.

- Available 09:00–23:55 daily; requirement Level 40 of second rebirth; Splinter at Twin City (392,324).
- Five forces; each has phases requiring 200, 500 and 1,000 killing points.
- Full phase permits summoning up to three Chiefs; killing five Chiefs upgrades Mayhem Lord by one phase, up to Phase 3.
- Mayhem Lord summon listed at 18:30.
- Feat points: Dogface 1, Elite 5, Chief 50, Mayhem Lord 100; each 50 points allows one pack, up to ten daily; top ten receive extra rewards.

This is a staged multi-target activity with boss scheduling and claim thresholds.

### 2.6 Epic Quest — Ninja

Source: https://comobile.99.com/guide/info/quests/2023-02-16/quest_-_ninja_epic_quest.shtml  
Status: MOBILE_OFFICIAL.

- Level 70+ second rebirth; Wind Sage in Twin City (388,316); Divine Shadow and Swapper Starry in Infinite Abyss.
- Three sequential trials: YinYang Seal → Elemental Jade → Life's Eye.
- Red/White Flowers are required to begin; the guide mentions Evil Abyss as a source.
- Each described trial has a 10% success chance; failure returns the player to an earlier trial.
- Stardust is an alternate failure output and can be exchanged with Swapper Starry; scrolls include Shadow Clone, Twilight Dance and Fatal Spin.
- Life's Eye transforms a Katana into the Epic Weapon Nobunaga's Claw.

### 2.7 Epic Quest — Taoist

Source: https://comobile.99.com/guide/info/quests/2023-02-16/quest_-_taoist_epic_quest.shtml  
Status: MOBILE_OFFICIAL.

- Level 70+ second rebirth; Taoist Moon, Twin City (381,318), leads to Taoist Temple.
- Named actors/objects: Sun King; Refined Pure Oven; Elite Pure Oven; Super Pure Oven; Pure Taoist.
- Three-stage chain: 3 Red + 3 White Flowers → Treasure Leaf → Star Crystal → Divine Panacea.
- Each stage documents a 10% success chance; failures require retrying the preceding crafting stage.
- Yin Yang Fish is an alternate outcome/exchange path with Pure Taoist.
- Divine Panacea transforms the Taoist Backsword; scrolls unlock Water/Fire Taoist skills.

### 2.8 Epic Quest — Monk

Source: https://comobile.99.com/guide/info/quests/2023-02-16/quests_-_monk_epic_quest.shtml  
Status: MOBILE_OFFICIAL.

- Level 70+ second rebirth; Head Abbot, Twin City (383,315), leads to Western Paradise.
- Named actors/objects: Golden Cicada, Fortune Arhat, Altar Cleanser, Victory Buddha, White Dragon; latter also appears in Oriental Fairyland.
- Three item trials: Red/White Flowers → Spiritual Gem → Buddha's Necklace → Boundless Heart.
- Failure returns to the preceding stage; Rosewood Incense is an alternate failure output/exchange route with White Dragon.
- Boundless Heart transforms the Monk's right-hand Bond; left-hand transformation requires repeating the chain. Skill scrolls unlock Monk-specific skills.

### 2.9 Inspiring Quest — Trojan

Source: https://comobile.99.com/guide/info/quests/2023-02-16/inspiring_quests_-_trojan_inspiring_quest.shtml  
Status: MOBILE_OFFICIAL.

- Level 45+; Aeneas, Twin City (441,379); entered through the Inspiration Guide button.
- Guide describes a guiding quest that unlocks Inspiration and Trojan Red Rune Berserk plus time-limited appearance rewards.
- This is a UI-entry-point and NPC-guided unlock, not merely an NPC talk objective.

### 2.10 Labyrinth quest/activity — New Evil Labyrinth

Source: https://comobile.99.com/guide/2023-08-29/new_evil_labyrinth.shtml  
Status: MOBILE_OFFICIAL event/update documentation; check pinned-client revision.

- Level 110+; Simon at Twin City (431,405) enters the Labyrinth quest map; Dark Furnace at Twin City / Endless Tower supports related crafting.
- Describes a daily/random-location Evil Chief spawn across Labyrinth floors 2–4, four-hour respawn rules, participation rewards, and a quest optimization changing daily targets.
- This is evidence for a separate map/activity quest family and target search, not a stable permanent boss coordinate.

### 2.11 Time-limited/event examples

These are source-backed patterns, not automatically active quests in the offline game. Expired events remain archived/inactive unless the pinned reference and project scope explicitly authorize a recreation.

- **Beast Scramble / Realm Quests (Aug–Sep 2023):** https://comobile.99.com/guide/2023-08-03/beast_scramble_-_unite_for_the_realm_and_compete_to_be_the_strongest_.shtml — Minor Lineage unlocked and level 15+; Hans/Vance in Twin City; daily realm tasks include Thunder Strike, Ashes of Anger, Defeat Beasts and Realm Construction, with combat, destruction, collection and point goals.
- **Sea Treasure Hunt (Aug 2024):** https://comobile.99.com/guide/2024-07-26/sea_treasure_hunt.shtml — level 80 / second-rebirth level 20 gates for Sea Vault/Abyss Vault; YuKoon; protectors, monster hunts, currencies and exchange.
- **Twinkling Fest (Feb 2026):** https://comobile.99.com/guide/2026-02-05/join_the_twinkling_fest_and_start_an_amazing_adventure.shtml — Level 80; Suyi in Twin City; Snowland shard collection and event progression.
- **Love Cycles (Sep 2026):** https://comobile.99.com/guide/2026-09-03/love_cycles_is_now_live_from_sept__8th_to_sept__21st_.shtml — Level 80; Suyi; seven daily-unlocking Beast Lineage Awakening quests, daily active-point gate, repeatable bridge repair, stage rewards and ranking points.
- **Into Wilds (Sep–Oct 2026):** https://comobile.99.com/guide/2026-09-24/join_into_wilds_now_for_generous_rewards_from_sept__29th_to_oct__12th_.shtml — Level 80; Eloise in Wind Plain; exploration stamina, consumable manuals, multiple exploration stages and success/failure progression.
- **New Server Bash (Jan 2024):** https://comobile.99.com/guide/info/quests/2024-01-05/new_server_-_new_server_bash.shtml — level/rebirth milestone reward claims; retain as welfare/progression claim family rather than inventing a quest chain.
- **New Server Carnival (Apr 2024):** https://comobile.99.com/guide/info/quests/2024-03-25/new%20server%20spheres%20carnival.shtml — temporary server-launch progression tasks and rewards.

## 3. Coverage gaps — not yet exhaustive

The official Mobile guide index currently exposes four Daily Quests, three Epic Quests, one Inspiring Quest, and separate Trials/Welfare/Maps/Systems sections. The Main Quest in Spheres is a separate official long-term storyline guide. Search also found many event-specific and feature-specific quest pages.

Still to enumerate and verify against the pinned client:
- Every sub-step and branch of Main Quest in Spheres, including NPC speech/options and reward transactions.
- Every generated Bounty Hall template/record, not just the five published objective families.
- Other daily/weekly/repeatable activities and quest-like trials; confirm whether they are classified as quests or standalone activities in the pinned UI.
- All map/zone quests, boss quests, class-specific quests beyond the three Epic families and Trojan Inspiring Quest, rebirth quests, sub-class tasks, house/equipment bonus questlines, tutorial/newcomer tasks and seasonal events.
- Historical and current Mobile event guides must be searched by date and checked for expiration/revision.
- Official guides can omit exact target IDs, monster spawn lists, dialogue scripts and some rewards. These must be sourced from the pinned client or corroborated runtime evidence before being admitted.

Legacy PC quest lists are discovery leads only. They are not a Mobile checklist and must not be copied wholesale into the Mobile catalogue.

## 4. Technical references and limits

### 4.1 Legacy Conquer PC DAT documentation — comparison only

- https://conquer-online.github.io/wiki/files/formats/dat.html
- https://conquer-online.github.io/wiki/security/tqfile.html

These references explain that legacy PC DAT files can be plaintext, binary, SWF, TQ File Cipher or RSA encrypted, and that TQ File Cipher is only applicable to files identified as using that cipher with the correct seed. This does **not** establish the Android 1.1.2.3 quest file format, encryption, field order or key. Never apply the PC cipher/seed to Mobile quest resources without Android reader proof.

### 4.2 What is actually known about our pinned Android quest files

The existing fidelity gate records candidate files `questinfo.dat` (default/Spanish/Arabic variants) and `taskitem_info.dat`. Earlier candidate decoding produced Lua-like signatures under a seed borrowed from older PC research, but `accepted_as_mobile_format=false`. Candidate counts (341 keyed entries and 10 task-item rows) are explicitly unapproved and must not be used as a runtime quest catalogue.

Required next technical steps:
1. Re-open the pinned APK and record SHA-256 for each quest-related asset, split/OBB or extracted resource, plus exact paths and byte offsets.
2. Identify the Android code path that opens/decodes the files; locate cipher selection, key/seed, decompression, serialization and record reader.
3. Validate a parser against multiple independent records and cross-check IDs/text with in-client screens or the official Mobile guide.
4. Resolve task/objective records to NPC, map, monster, item, skill, reward and follow-up registries from the same client build.
5. Preserve original opaque keys and unknown fields. Unknown is not zero, false, or a safe default.
6. Keep source extraction/research output separate from the runtime-approved catalogue until all checks pass.

### 4.3 Proposed engine-neutral data model (schema proposal, not claimed source format)

A quest record should be declarative and preserve source semantics:

```json
{
  "schema_version": 1,
  "quest_id": "source-stable-id-required",
  "source": {
    "evidence_class": "MOBILE_OFFICIAL",
    "source_uri": "https://...",
    "client_version": "unverified",
    "source_file": null,
    "source_sha256": null,
    "record_key": null,
    "confidence": "documented_feature_not_client_verified"
  },
  "category": "main|side|daily|weekly|class|rebirth|zone|boss|trial|event|tutorial|welfare",
  "availability": {
    "duration": "long_term|scheduled|date_window|repeatable",
    "start_utc": null,
    "end_utc": null,
    "reset_policy": null,
    "daily_limit": null,
    "storage_cap": null
  },
  "gates": {
    "level_min": null,
    "level_max": null,
    "rebirth": null,
    "class_ids": [],
    "prerequisite_quest_ids": [],
    "required_unlock_ids": [],
    "map_id": null
  },
  "giver": {"npc_id": null, "ui_entry_id": null},
  "steps": [
    {
      "step_id": "source-step-key-required",
      "order": 0,
      "kind": "talk|deliver|kill|hunt|collect|submit|interact|craft|use_item|reach_level|score|survive|timed_round|boss|unlock|claim",
      "target": {
        "type": "npc|monster|monster_group|item|object|area|map_exit|activity|ui",
        "id": null,
        "map_id": null,
        "region_id": null,
        "approach_anchor_id": null,
        "interaction_range": null
      },
      "quantity": null,
      "consume_item_ids": [],
      "conditions": [],
      "on_success": [],
      "on_failure": [],
      "failure_policy": null,
      "dialogue_branch_id": null
    }
  ],
  "turn_in": {"npc_id": null, "dialogue_branch_id": null, "explicit_claim_required": null},
  "rewards": [],
  "follow_up_quest_ids": [],
  "localization": {"title": {}, "description": {}, "dialogue": {}},
  "runtime_admission": "UNRESOLVED"
}
```

This is our normalized integration contract, not a claim that the original client uses JSON or these exact field names. Each field must map to a verified source field or remain null/unresolved. The runtime navigation resolver reads the current step's typed target and stable IDs; it does not derive targets from quest names or hard-coded coordinates.

## 5. Required objective handlers

The mobile evidence already requires at least these independent handlers:

- NPC talk / message delivery with selected dialogue branch and explicit action result.
- Item inventory possession vs item consumption/submission (distinct semantics).
- Kill counter vs hunt-in-region counter (distinct target filters).
- Area collection and world-object interaction.
- Timed scoring / defence session with stun effects and score.
- Scheduled multi-round activity, entry caps, island/stage progression and rewards.
- Multi-phase force progression, chief summon, boss schedule, feat points and daily claim caps.
- Probabilistic item transformation with explicit retry/failure branches.
- Skill/system unlock and UI-button initiated quest.
- Event-date availability, daily unlock sequence, activity threshold and staged rewards.
- Cross-map transition through a validated exit/portal/transport target, not direct teleport to an arbitrary objective.

A task's movement target is only navigable if its current step contains a verified target identity, map identity and approach anchor. For NPC steps, the NPC catalogue/placement registry must resolve the source NPC ID. For area objectives, a separately authored and verified region/approach anchor is required. A visual landmark or generic road is never an objective by default.

## 6. Preservation constraints

- Do not rewrite existing quest rules, requirements, rewards, or dialogue presentation when the requested change is navigation/data integration.
- Keep the original HUD, quest tracker, NPC/player speech bubbles, dialogue choices and interaction flow as the presentation contract. New data must bind into these surfaces; it must not create a parallel generic quest UI.
- Keep Travel Scroll/instant travel separate from world-tap and quest auto-walk. A quest that crosses maps must target its evidenced exit/portal/transport step.
- Keep Gold-only and offline constraints. Online rankings, CP purchases, account/server competition and external services are not copied as online dependencies; any offline adaptation must be explicitly designed and reviewed.
- Never activate expired seasonal events by default.
- Preserve all original rewards/requirements in the reference catalogue; mark out-of-scope mechanics rather than silently deleting or substituting them.

## 7. Acceptance gates

A catalogue record may progress only through:
`DISCOVERED` → `SOURCE_CAPTURED` → `SCHEMA_VERIFIED` → `ID_MAPPED` → `IMPLEMENTED` → `RUNTIME_TESTED` → `UI_VISUALLY_REVIEWED` → `APPROVED`.

A quest cannot be APPROVED if:
- its source/version or source hash is unknown where client data is claimed;
- any required step/branch/reward/prerequisite is missing;
- target IDs do not resolve to the correct world map entities;
- navigation points to a guessed coordinate, landmark, road or map center;
- dialogue/bubble/UI states differ from the pinned reference without an explicit approved adaptation;
- reward claims are not idempotent across save/load/replay;
- Android runtime behavior has not been tested.

## 8. Research sources

**Official Conquer Online Mobile**
- Guide index: https://comobile.99.com/guide/info/info.shtml
- Main Quest in Spheres: https://comobile.99.com/guide/2024-03-19/main_quest_in_spheres.shtml
- Bounty Hall: https://comobile.99.com/guide/info/quests/2023-01-31/daily_-_bounty_hall.shtml
- Farmland Defence: https://comobile.99.com/guide/info/quests/2023-01-31/daily_-_farmland_defence.shtml
- Hunting Battle: https://comobile.99.com/guide/info/quests/2023-01-31/daily_-_hunting_battle.shtml
- Mayhem Land Crusade: https://comobile.99.com/guide/info/quests/2023-01-31/daily_-_mayhem_land_crusade.shtml
- Ninja Epic Quest: https://comobile.99.com/guide/info/quests/2023-02-16/quest_-_ninja_epic_quest.shtml
- Taoist Epic Quest: https://comobile.99.com/guide/info/quests/2023-02-16/quest_-_taoist_epic_quest.shtml
- Monk Epic Quest: https://comobile.99.com/guide/info/quests/2023-02-16/quests_-_monk_epic_quest.shtml
- Trojan Inspiring Quest: https://comobile.99.com/guide/info/quests/2023-02-16/inspiring_quests_-_trojan_inspiring_quest.shtml
- New Evil Labyrinth: https://comobile.99.com/guide/2023-08-29/new_evil_labyrinth.shtml
- Beast Scramble: https://comobile.99.com/guide/2023-08-03/beast_scramble_-_unite_for_the_realm_and_compete_to_be_the_strongest_.shtml
- Sea Treasure Hunt: https://comobile.99.com/guide/2024-07-26/sea_treasure_hunt.shtml
- Twinkling Fest: https://comobile.99.com/guide/2026-02-05/join_the_twinkling_fest_and_start_an_amazing_adventure.shtml
- Love Cycles: https://comobile.99.com/guide/2026-09-03/love_cycles_is_now_live_from_sept__8th_to_sept__21st_.shtml
- Into Wilds: https://comobile.99.com/guide/2026-09-24/join_into_wilds_now_for_generous_rewards_from_sept__29th_to_oct__12th_.shtml

**Legacy / non-Mobile technical comparison only**
- DAT formats: https://conquer-online.github.io/wiki/files/formats/dat.html
- TQ File Cipher: https://conquer-online.github.io/wiki/security/tqfile.html
- PC quest lists are not accepted as Mobile catalogue entries.

**Internal project gates**
- `ASSET_REFERENCE_LIBRARY/QUEST_EXTERNAL_EVIDENCE_2026-11-07.md`
- `ASSET_REFERENCE_LIBRARY/QUEST_SYSTEM_FIDELITY_GATE.md`
