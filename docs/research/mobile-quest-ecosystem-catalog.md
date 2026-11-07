# Conquer Online Mobile quest ecosystem — research catalogue

**Target client:** `com.Tq.CQ2ClientAndroid`, version `1.1.2.3` (version code 123)  
**Research branch:** `research/mobile-quest-dat-decoder`  
**Purpose:** version-aware reference index for reconstructing the quest library and its links to NPCs, maps, monsters, items, rewards, progression and unlocks.

> Evidence policy: official Mobile guides are behavioral/reference evidence, not proof of the exact 1.1.2.3 resource schema. Older PC-client documentation is never promoted to Mobile truth. Every extracted file, field, ID join and cipher format must be checked against the exact Mobile APK/resources and, where possible, the Android reader.

## 1. Exact target identity

Public Android package listings identify the app as `com.Tq.CQ2ClientAndroid`, version `1.1.2.3 (123)`, updated 2026-07-21. APKPure reports SHA-256 `b087b66abb20120a09d90f5b3c155adc3819c11a2ad5737eb3a0b576f2c424de` for its listed package; APKFab lists an XAPK bundle and base APK split. These are external package fingerprints, **not** a replacement for the locally supplied extracted-assets archive fingerprint.

- APKPure version history: https://apkpure.net/conquer-online-mmorpg-game/com.Tq.CQ2ClientAndroid/versions
- APKFab package/split listing: https://apkfab.com/conquer-online/com.Tq.CQ2ClientAndroid

## 2. Official Mobile quest catalogue discovered

The official Mobile guide index lists these sections: Daily Quests (Bounty Hall, Farmland Defence, Hunting Battle, Mayhem Land Crusade); Trials (Chi Canyon, Battle Dojo, Rune Mountain); Epic Quests (Ninja, Taoist, Monk); Inspiring Quests (Trojan Inspiring Quest). This index is a discovery checklist, not a claim that every activity is a conventional story quest.

Source: https://comobile.99.com/guide/info/info.shtml

### 2.1 Main narrative and progression spine

**Main Quest in Spheres** — all players; long-term.

Known guide anchors:
- Eloise — Twin City (441,379), main-quest guidance.
- Dunn Berg — Twin City (383,346), main-quest guidance.
- Early NPC chain includes Song Qing, Song Shiyu, Lieutenant Chen, Li Kui and Li Gui.
- Newcomer stage: levels 1–50; introduces NPCs, equipment upgrading/composition and first mount.
- Stepping Stone: levels 50–75; Wind Plain and Maple Forest; gem and sub-class systems; Twilight Towers.
- Reaching Delight: levels 75–130; return to Twin City, Den Berg/Spheres progression; rebirth, lineage and daily activities including Deathtrap.
- Stable Progress: levels 1–60 of first rebirth; Enigma Domains, Ether Spirit, Ethersuit, Ethercore, Mine Contest and Cyclical Trial.
- Scaling New Heights: levels 60–130 of first rebirth; second-rebirth class, perfection, Chi and soul systems; Mayhem Land and Evil Labyrinth.
- Ultimate Achievement: levels 1–140 of second rebirth; Jiang Hu, Rune and Inner Power systems.
- Peak of Glory: 140+ of second rebirth; continuing storylines.

Primary source: https://comobile.99.com/guide/2024-03-19/main_quest_in_spheres.shtml

**Implementation implication:** model this as a progression graph, not a flat quest list. Quest nodes should be able to unlock systems, maps, activities, class features and follow-up NPC dialogue. Level/rebirth/Sphere gates must be represented separately from objective completion.

### 2.2 Daily quests

**Bounty Hall**
- Level 80+.
- Chinju — Twin City (443,293), or the Bounty Hall entrance button.
- Three random quests are available daily, selected from Easy/Normal/Hard/Expert tiers.
- Quest archetypes explicitly documented: message delivery to an NPC; collecting materials at a required place; killing required monsters; submitting items dropped by monsters; hunting monsters in the wild.
- Trojan-only branch is gated by completion of the Trojan inspiring quest and Weapon Spirit unlock; includes monster kills, item collection, boss hunting, item submission.
- Six quests added per day; storage cap 18; current quests must be completed or abandoned before taking/refeshing the next set; Go button supports pathfinding.

Primary source: https://comobile.99.com/guide/info/quests/2023-01-31/daily_-_bounty_hall.shtml

**Farmland Defence**
- Level 50.
- Roberts — Twin City (349,342).
- Once daily, 60-second pest elimination.
- Evil Locust: 3 points; Evil Aphid: 1 point; Evil Bee: 0 points and 3-second stun.
- Rewards include EXP/study points/items; top five daily ranking receives Dragon Ball (B) by mailbox.

Primary source: https://comobile.99.com/guide/info/quests/2023-01-31/daily_-_farmland_defence.shtml

**Hunting Battle**
- Level 130+; entrance via Hunting Battle button; long-term activity.
- Four daily event windows in the 2023 guide: 13:00–13:15, 16:00–16:15, 19:00–19:15 and 22:00–22:15; two rounds per character per day.
- Forthy Ground contains Islands 1–3. Accumulate 100 Hunting Points to advance from Island 1 to 2 (points consumed), then 200 to advance to Island 3 (points consumed); stage rewards unlock at cumulative 100/200/300 and are claimable once daily.
- Normal monster: 1 point; elite: 5; boss: 50 (boss spawns at map center at minutes 1, 6 and 11); defeating another hero: 10 plus 20% of that target's points.
- A later official patch note (Patch 3822, Nov. 12, 2024) says Island 3 was temporarily replaced by the larger Glory Island for a special mode. Treat that as a dated variant, not permanent base behavior.

Sources: https://comobile.99.com/guide/info/quests/2023-01-31/daily_-_hunting_battle.shtml and https://comobile.99.com/patch/2024-11-07/patch_3822_-_legendary_competition__version_bonus__inner_power_wheel_and_more.shtml

**Mayhem Land Crusade**
- Daily window: 09:00–23:55; requirement: level 40 of second rebirth.
- Splinter — Twin City (392,324).
- Five forces; each is cleared through phases requiring 200, 500 and 1,000 Killing Points. One Elite kill grants one Killing Point.
- Completing each phase allows up to three Chiefs to be summoned. Killing five Chiefs advances Mayhem Lord by one phase, up to phase 3; Mayhem Lord can be summoned at 18:30.
- Feat Points: Dogface 1, Elite 5, Chief 50, Mayhem Lord 100. Each 50 Feat Points allows one reward pack, up to 10 daily; top 10 receive extra ranking rewards.
- The Main Quest in Spheres guide separately lists Mayhem Land as an activity unlocked during Scaling New Heights. Do not collapse the daily Crusade and the progression unlock into one quest record without checking the client data.

Source: https://comobile.99.com/guide/info/quests/2023-01-31/daily_-_mayhem_land_crusade.shtml

### 2.3 Trials and repeatable challenges

**Chi Canyon**
- Trials button; two free challenge chances per day or entry using Purple Sage.
- Three monster difficulty levels; 100/200/300 points per kill by tier; 180-second challenge.
- Rewards include Tiger Chi Liquor and Mystic EXP Balls.

Source: https://comobile.99.com/guide/info/quests/2023-01-31/trials_-_chi_canyon.shtml

**Battle Dojo**
- Trials button; two free chances daily or Dojo Challenge Letter.
- Activate dojo array to summon masters; after defeating a master the array refreshes.
- Up to four master challenges; 180 seconds per round; score/rewards depend on completion time.
- Rewards include training pills and Mystic EXP Balls.

Source: https://comobile.99.com/guide/info/quests/2023-01-31/trials_-_battle_dojo.shtml

**Rune Mountain**
- Trials button; one free attempt daily or entry using Rune Challenge Letter.
- Four waves of Bushfire Beasts must be defeated; Lich Kings appear after all four waves; defeating them awards Yellow Rune Essences.

Source: https://comobile.99.com/guide/info/quests/2023-01-31/trials_-_rune_mountain.shtml

### 2.4 Class epic and inspiration quests

**Ninja Epic Quest**
- Level 70+ second rebirth Ninja.
- NPCs: Wind Sage (Twin City 388,316), Divine Shadow (Infinite Abyss 28,33), Swapper Starry (Infinite Abyss 27,40).
- Quest items include Red Flower, White Flower, YinYang Seal, Elemental Jade, Life's Eye, Stardust and skill scrolls.
- Three-stage progression through Infinite Abyss / Evil Abyss; creates or upgrades the Ninja Epic Weapon and unlocks skills.

Source: https://comobile.99.com/guide/info/quests/2023-02-16/quest_-_ninja_epic_quest.shtml

**Taoist Epic Quest**
- Level 70+ second rebirth Taoist.
- NPCs: Taoist Moon (Twin City 381,318); Sun King, Refined Pure Oven, Elite Pure Oven, Super Pure Oven and Pure Taoist in Taoist Temple.
- Crafting chain: Red/White Flowers → Treasure Leaf → Star Crystal → Divine Panacea; failure path can yield Yin Yang Fish.
- Water/Fire Taoist skill scroll branches.

Source: https://comobile.99.com/guide/info/quests/2023-02-16/quest_-_taoist_epic_quest.shtml

**Monk Epic Quest**
- Level 70+ second rebirth Monk.
- NPCs: Head Abbot (Twin City 383,315); Golden Cicada, Fortune Arhat, Altar Cleanser, Victory Buddha in Western Paradise; White Dragon in Oriental Fairyland.
- Item chain: Red/White Flowers → Spiritual Gem → Buddha's Necklace → Boundless Heart; alternate Rosewood Incense exchange path.
- Separate left-hand weapon repeat requirement is documented.

Source: https://comobile.99.com/guide/info/quests/2023-02-16/quests_-_monk_epic_quest.shtml

**Trojan Inspiring Quest**
- Level 45+.
- Aeneas — Twin City (441,379); Inspiration Guide button.
- Completion unlocks Inspiration; reward examples include Trojan Red Rune “Berserk” and time-limited cosmetics.

Source: https://comobile.99.com/guide/info/quests/2023-02-16/inspiring_quests_-_trojan_inspiring_quest.shtml

## 3. World entities and relationships to extract

Every quest record should be joined, only after source validation, to:
1. NPC definitions: stable NPC ID, display name/localization, map ID, coordinates, role, dialogue/script reference, interaction options and teleport behavior.
2. Map definitions: stable map ID, resource path, display name, entry/exit links, valid coordinate bounds and pathfinding/navigation data.
3. Monster definitions: stable monster ID, spawn/map references, kill counters, boss flags, drops and quest-only variants.
4. Item definitions: stable item/type ID, localized name/description, stackability, bind/trade/storage rules, quest-item flag and source/drop/submit/use relationships.
5. Reward definitions: item/currency/EXP/point bundles, tier, claim limits, mailbox delivery and failure/alternate rewards.
6. Progression gates: level, rebirth, class, Sphere, prior quest completion, daily reset/attempt counters and system unlock flags.
7. Dialogue graph: NPC → dialogue node → option → condition → objective mutation → next node/teleport/reward.
8. Objective graph: talk, deliver, collect, kill, boss kill, submit, interact, reach map/coordinates, timed score, craft/transform, challenge stage.

Do not treat equal-looking numeric fields as the same ID namespace until their source tables and reader usage prove the relationship.

## 4. Candidate resource paths and current gaps

The current repository tools look for exact Mobile APK members under `assets/ConquerRes/`, including candidate names such as:
- `ini/luacfg/questinfo.dat`
- `ini/luacfg/taskitem_info.dat`
- `script/clienttaskNNNN.dat`
- `data/client_realm_task/juqingNN.dat`
- NPC/map/item/reward/dialogue-related INI, DAT, Lua and localization resources.

These names are **candidate conventions**, not verified proof that every file exists in Mobile 1.1.2.3. The inventory must also discover quest content stored under generic filenames or shared Lua/config bundles; filename keyword matching alone is insufficient.

Known gaps to close:
- Verify the exact 1.1.2.3 archive/APK member list and hashes against the supplied source bundle.
- Retrieve the actual GitHub Actions artifact from the quest inventory workflow and enumerate all matched resource paths.
- Search inside generic Lua/config/script bundles for quest signatures, dialogue tables and task IDs, not only paths containing “quest/task”.
- Determine the actual Mobile reader/cipher per file type; TQ File Cipher seeds 9527/1234 remain research probes only.
- Reconcile the 2023 official guide rules with later live patches and the exact 1.1.2.3 client; event times and map variants can change.
- Build NPC↔map↔quest↔monster↔item↔reward joins and report missing/orphan/duplicate references.
- Compare official guide behavior with the exact 1.1.2.3 APK; guides dated 2023–2024 may be stale relative to later updates.

## 5. Trust labels

Use these labels in all future reports:
- **MOBILE_OFFICIAL_GUIDE** — behavior or NPC/location stated on the official Mobile guide; guide date retained.
- **MOBILE_APK_OBSERVED** — resource/path/bytes directly present in the exact 1.1.2.3 APK; include member path and SHA-256.
- **MOBILE_READER_VERIFIED** — interpretation confirmed by the matching Android reader or runtime behavior.
- **CROSS_FILE_JOIN_VERIFIED** — references resolve across independently verified Mobile tables.
- **COMMUNITY_REFERENCE_ONLY** — community/PC material, never authoritative for Mobile.
- **UNVERIFIED_CANDIDATE** — filename, cipher probe, schema or inferred relationship awaiting proof.

No PC-client schema, seed, ID meaning, coordinates or dialogue logic is accepted as Mobile data without Mobile-side verification.
