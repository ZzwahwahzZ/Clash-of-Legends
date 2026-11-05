# CONQUER ONLINE FEATURE PARITY MATRIX
**Project:** Clash of Legends  
**Branch:** main  
**Baseline inspected:** 2026-11-05  
**Canonical reference:** Owner-supplied Android client snapshot `com.Tq.CQ2ClientAndroid`, `versionName=1.1.2.3`, `versionCode=123`; base APK SHA-256 `b1b8ccf0d5e1a9dcf346f8f11c20011cd9c68332f1b92676e79f87290f12c8f2`. Server-side content revision and regional variant remain unresolved.  
**Purpose:** Track feature-by-feature parity against the reference. This is an implementation inventory, not a claim that every feature in every Conquer release is known or complete.

## Status vocabulary
- **PARTIAL — prototype evidence exists:** a limited implementation was inspected; functional parity is not established.
- **MISSING — no implementation evidence inspected:** must be researched and built.
- **BLOCKED — external input required:** e.g. lawful reference data, a real asset package, hosting URL, or owner-side device test.
- **LICENSE REVIEW:** reference content may be proprietary; implement an original/authorized equivalent unless permission is documented.
- **VERIFIED:** only after implementation, integration, automated test, and offline acceptance evidence are recorded. No row is VERIFIED in this initial inventory merely because a file exists.

## Owner invariants (apply to every row)
1. Conquer Online is the primary feature and experience reference; do not silently omit a distinct system.
2. Final Android game is landscape and fully playable offline after optional first-launch content installation.
3. Internet may be used only by the first-launch content bootstrapper to obtain missing approved packages. Gameplay, saves, economy, NPCs, AI, events, guilds, marriage, and all other runtime systems must work with the device offline.
4. Gold is the only currency. Convert paid/premium acquisition routes into Gold, gameplay, quest, or event rewards.
5. No real players, online servers, matchmaking, chat of any kind, or friends list.
6. Guilds, marriage, parties/teams, gatherings, guild wars, tournaments, and events remain as deterministic local simulations.
7. Town population: 30–40 visible simulated characters maximum; normally 1–2 moving, hard cap 5–6 moving. Hunting grounds stay sparse. Large event crowds spawn only for the event and are removed afterward.
8. Preserve Conquer's recognizable gameplay roles and visual language while using original or properly licensed assets/data/dialogue. Never redistribute proprietary client files without permission.
9. No feature is complete because a panel, placeholder, mock, data stub, or isolated script exists.

## Feature parity inventory

| ID | Conquer reference domain / expected coverage | Current repository evidence (inspected) | Initial state | Required acceptance evidence |
|---|---|---|---|---|
| WORLD-01 | Twin City, city layout, landmarks, safe zones, portals and exits | `scenes/core/MainGame.tscn` contains a small procedural Twin City sample and a ground plane | PARTIAL | Reference-map coverage checklist; all areas traversable; collision/navigation checks |
| WORLD-02 | All documented cities, towns, maps, hunting fields and level bands | One small scene inspected; no complete map catalogue established | MISSING | Version-pinned map catalogue; each map implemented and visited in offline tests |
| WORLD-03 | Dungeons, caves, towers, instances, secret areas and boss arenas | One volcano/boss area sample in MainGame scene | PARTIAL | Full instance list, entry rules, exits, reset rules, encounter tests |
| WORLD-04 | Map transitions, portals, teleportation and return points | NPC role/quest navigation samples exist; no complete transition catalogue established | PARTIAL | Every transition resolves offline and restores correct spawn/return state |
| WORLD-05 | Terrain, minimap, collision, navigation and environmental hazards | Ground and a few meshes/colliders in MainGame scene | PARTIAL | Map-by-map collision, minimap, pathing and hazard checks |
| CLASS-01 | All reference classes, class identity, equipment compatibility and starting paths | TestRunner checks seven class names through CombatEngine skill lookup | PARTIAL | Pinned class catalogue; class creation, restrictions, equipment and progression tests |
| CLASS-02 | Promotions, rebirth/rebirth-like progression, class advancement and level gates | No complete progression catalogue established | MISSING | Full rules and migration/save tests |
| CLASS-03 | Character creation, appearance, body/face/hair and identity choices | Player scene exists; full appearance catalogue not verified | PARTIAL | Character-creation matrix and persisted appearance tests |
| SKILL-01 | Complete class skill/spell catalogue, unlocks, ranks, costs, cooldowns, range and targeting | `scripts/combat/CombatEngine.gd` contains a skill database; TestRunner checks one sample skill and per-class non-empty lists | PARTIAL | Every skill enumerated from pinned reference; data validation and per-skill execution tests |
| SKILL-02 | Buffs, debuffs, status effects, healing, mana and duration rules | CombatEngine exists; full effect catalogue not verified | PARTIAL | Effect stacking, expiry, cleanse, death and save/load tests |
| SKILL-03 | Skill animations, projectile/travel behavior, VFX and sound cues | Sample 3D combat assets and shader exist; complete mapping absent | PARTIAL | Skill-to-animation/VFX/audio coverage report |
| COMBAT-01 | Targeting, basic attacks, attack speed, hit checks, range, defense and damage | PlayerController, CombatEngine and MonsterBase exist | PARTIAL | Deterministic combat matrix covering hit/miss, range, armor, critical and death |
| COMBAT-02 | PvE monster aggro, leash, spawn, respawn and hunting behavior | MonsterBase and wolf/dragon scenes exist | PARTIAL | Per-monster behavior and spawn/respawn tests |
| COMBAT-03 | PvP modes and competitive combat rules adapted to local simulation | No full PvP mode inventory inspected; no real players allowed | MISSING | Local AI opponent rules, arena/duel acceptance, no network dependency |
| MON-01 | Full monster families, variants, levels, resistances and habitats | WildWolf and BossDragon scenes inspected | PARTIAL | Monster roster with per-entry stats, model, animation, spawn and drop validation |
| MON-02 | Boss roster, mechanics, phases, summons, rewards and respawn | BossDragon sample exists | PARTIAL | Boss catalogue and encounter-by-encounter tests |
| DROP-01 | Item drops, rarity, weighted tables, Gold drops and loot rules | LootDrop3D and AutoLootManager exist | PARTIAL | Deterministic seeded drop tests; no duplicate/invalid reward paths |
| QUEST-01 | Main, side, repeatable, class, daily/weekly-style, event and progression quests | QuestNavigationAgent has a four-step offline sample chain | PARTIAL | Reference-version quest index, dialogue/objective/reward coverage and save tests |
| QUEST-02 | Quest NPC placement, prerequisites, branching, abandonment and turn-in | NPCBase and DialogueUI exist; quest-to-NPC completeness not established | PARTIAL | Every quest mapped to NPC, prerequisite, branch, objective and turn-in tests |
| NPC-01 | Sage, merchants, blacksmith, trainers, teleporters, warehouse and service NPC roles | NPCBase role dispatch and sample NPCs exist | PARTIAL | NPC roster and role-specific end-to-end interaction tests |
| NPC-02 | Dialogue trees, localized lines, choices and quest/shop actions | DialogueUI and NPCBase exist | PARTIAL | Dialogue coverage, valid choice routing, Arabic/English review |
| ITEM-01 | Full item catalogue, stack rules, item types, level/class requirements | PlayerInventory has a 40-slot prototype and sample item data | PARTIAL | Complete item database, constraints, stack/merge/split/drop tests |
| EQUIP-01 | Weapon, armor, headgear, necklace, ring, boots, shield and accessory slots | PlayerInventory equipment model exists | PARTIAL | Slot compatibility, stat derivation, equip/unequip and persistence tests |
| REFINE-01 | Refinement levels, costs, odds, failure outcomes, protection and visual tiers | BlacksmithUI and weapon glow shader exist; exact rules not established | PARTIAL | Reference-based refinement table, seeded probability tests and visual tier checks |
| SOCKET-01 | Socket creation, hole count, insertion/removal, restrictions and bonuses | No verified complete socket system inspected | MISSING | Socket lifecycle, legal item/gem combinations and stat recalculation tests |
| GEM-01 | Gem families, grades, effects, upgrades and visual indicators | No verified complete gem catalogue inspected | MISSING | Full gem matrix and effect/upgrade tests |
| FASHION-01 | Outfit/fashion catalogue, appearance layers, dyes and acquisition | No complete fashion catalogue inspected | MISSING | Every approved outfit has asset, preview, equip, reward/shop and save evidence |
| MOUNT-01 | Starter horse acquisition/upgrades, riding, movement and animations | GameManager translation includes mount; full mount implementation not verified | MISSING | Starter horse lifecycle and mounted movement/animation tests |
| MOUNT-02 | Separate spirit-beast/collectible mounts, skills, effects and acquisition | No complete mount roster inspected | MISSING | Separate catalogue and riding/effect/persistence tests |
| INV-01 | Inventory capacity, sorting, split/stack, discard, item details and filters | PlayerInventory prototype and InventoryUI exist | PARTIAL | Full inventory interaction and edge-case tests |
| STORE-01 | Personal storage/warehouse, capacity, deposit/withdraw and persistence | No verified warehouse implementation inspected | MISSING | Offline storage transaction and save recovery tests |
| CRAFT-01 | Crafting, composing, upgrading, material conversion and recipes | No complete crafting catalogue inspected | MISSING | Recipe catalogue, material/cost validation and output tests |
| SHOP-01 | NPC shops, buying/selling, stock, pricing and restrictions | NPC role sample and InventoryUI exist | PARTIAL | All vendor categories, transaction rollback and Gold accounting tests |
| MARKET-01 | Player-like stalls, search, listing, purchase and price validation | No complete local market implementation inspected | MISSING | Local vendor simulation, deterministic stock and transaction tests |
| MARKET-02 | Black Market search, listing, rarity, refresh and purchase | Blacksmith/UI references are not evidence of Black Market | MISSING | Search/filter/buy tests, Gold-only economy, offline availability |
| ECON-01 | Gold sources/sinks, prices, taxes/fees and economic balance | GameManager implements local add/spend Gold | PARTIAL | Complete Gold ledger, exploit checks, reward/sink balancing |
| ECON-02 | CP, VIP, premium gems, cash shop and paid-only acquisition | Owner explicitly excludes premium currency and real-money purchases | OWNER-OVERRIDE | Prove no premium/payment path remains; map every premium item to gameplay/Gold |
| PARTY-01 | Team formation, invites, roles, shared rewards and party combat | No complete party system inspected | MISSING | Local deterministic team simulation and reward distribution tests |
| GUILD-01 | Guild creation, joining, ranks, permissions, contribution and upgrades | No complete guild implementation inspected | MISSING | Full guild lifecycle, offline roster and save/load tests |
| GUILD-02 | Guild activities, competitions, wars, territory and rewards | No complete guild-war implementation inspected | MISSING | Event-driven local battles, crowd lifecycle and result/reward tests |
| SOCIAL-01 | Marriage, proposal, ceremony, benefits and persistence | Owner requires marriage; no complete implementation inspected | MISSING | Local marriage lifecycle and save/load tests |
| SOCIAL-02 | Friends, private/world/trade chat and messaging | Explicitly prohibited by owner | EXCLUDED | Static/source audit confirms no chat UI, message pool, signal or runtime path |
| EVENT-01 | Tournaments, arenas, scheduled and seasonal events, event bosses | No complete event catalogue inspected | MISSING | Offline schedule/state machine, registration, brackets, rewards and cleanup tests |
| PROG-01 | XP, level curves, attributes, skill points and level caps | PlayerController and GameManager have stat paths; full curves unverified | PARTIAL | Versioned progression tables, boundary and save tests |
| PROG-02 | Titles, achievements, milestones and collection rewards | No complete achievement/title system inspected | MISSING | Achievement catalogue, trigger tests and reward persistence |
| UI-01 | Reference-style HUD, target frame, status bars, quest tracker and menus | MainHUD and controllers exist; recent interact button added | PARTIAL | Screen-by-screen feature inventory and Android landscape usability test |
| UI-02 | Free 360-degree camera, zoom, touch gestures and camera collision | FreeCamera3D exists | PARTIAL | Full rotation/zoom/obstacle/mobile gesture tests |
| AUDIO-01 | Music, ambient audio, combat, skill, UI and mount sounds | Audio/VFX pack is only a planned manifest entry; actual package absent per prior reconciliation | BLOCKED | Licensed/original audio catalogue, verified package hashes and in-game coverage |
| VFX-01 | Skill effects, weapon refinement glow, impacts, weather and environment effects | Weapon glow shader and sample environment effects exist | PARTIAL | Per-feature VFX checklist and low-end Android performance checks |
| SAVE-01 | Character, inventory, equipment, quests, Gold, guild, marriage, settings and world persistence | LocalSaveEngine JSON primary/backup exists; complete state integration unverified | PARTIAL | Versioned schema, corruption recovery, migration and offline round-trip tests |
| OFFLINE-01 | No gameplay network calls, no server/account/matchmaking dependency | GameManager and save engine are local; Android export currently has INTERNET=false | PARTIAL | Runtime network audit plus airplane-mode full playthrough |
| BOOT-01 | First-launch optional content download, integrity checks, retry/resume, local install and offline lock | No bootstrapper inspected; export currently has INTERNET=false; RESOURCE_MANIFEST hashes appear patterned/demo and must not be trusted | MISSING / BLOCKED | Real HTTPS package host, real byte sizes/SHA-256, atomic install, resume tests, then airplane-mode launch |
| POP-01 | Town population and sparse field population under owner limits | SimulatedPlayer is command-driven; full population manager/caps not verified | PARTIAL | Runtime counters prove 30–40 total / 5–6 movers max and event cleanup |
| PERF-01 | LOD, culling, instancing, animation throttling, memory budgets | No complete profiling evidence inspected | MISSING | Profiling on target Android device, frame-time/memory reports |
| ACCESS-01 | Arabic/English, RTL, touch target sizing and accessibility | Arabic/English locale support exists in core | PARTIAL | Full UI translation audit, RTL screenshot review and touch usability test |
| BUILD-01 | Android ARM64 landscape package and install/update behavior | Android preset exists; landscape set; INTERNET permission currently false; no APK build evidence inspected in this pass | PARTIAL | Signed/unsigned release build validation, install/upgrade tests and offline acceptance |

## First-launch content installation contract

The owner's approved network boundary is narrow:
- Internet access is permitted only during first-launch content setup, and only to retrieve missing, approved game-content packages.
- Downloaded packages must be listed in a versioned manifest containing package ID, version, exact byte length, SHA-256, HTTPS URL, destination, required/optional flag, and compatible game version.
- The manifest itself must be authenticated (signed manifest or an equivalently trusted release channel); HTTPS alone does not protect against a compromised publishing account.
- Verify free storage before downloading. Show the player package sizes and total required storage.
- Download to a temporary `.part` file; resume only when the origin supports HTTP Range and the server confirms the correct Content-Range. Otherwise restart that individual package safely.
- Verify exact length and SHA-256 before installation. Reject mismatches and never load partial packages.
- Install atomically, record installed package versions/hashes locally, and preserve the previous valid package until the replacement passes verification.
- If interrupted, keep verified completed packages and resume eligible partial downloads next time.
- If a required package is unavailable or invalid, do not enter gameplay as though content were complete. Offer retry and a clear diagnostic.
- After required content is installed, the game must never request network access for gameplay. An airplane-mode launch and full gameplay test is a release gate.
- Do not place secrets or private tokens in the client. Package URLs must be public read-only release URLs or use an explicitly designed authenticated distribution method; no Hugging Face write token may ship in the APK.

## Critical blockers discovered in the current repository snapshot
1. `RESOURCE_MANIFEST` is present but contains patterned/demo-looking SHA-256 values. Treat every listed hash as **untrusted** until recomputed from the actual final package bytes.
2. The four PCK packages described by the existing reconciliation report were previously reported missing (0/4 present). Re-run the verifier when actual files are available; do not fabricate packages.
3. The manifest has no download URLs or authenticated release-manifest mechanism. A first-launch downloader cannot safely retrieve packages until a real hosting location and verified package hashes exist.
4. `export_presets.cfg` currently has `permissions/internet=false` and `permissions/access_network_state=false`. This correctly prevents networking today but must be changed deliberately when the bootstrapper is implemented and tested.
5. The inspected `LocalSaveEngine.gd` stores a generic player dictionary and backup, but the inspected evidence does not prove that every required subsystem (quest, guild, marriage, warehouse, market, world/event state) is actually serialized and restored.
6. The current inspected world is a small procedural sample, not a complete Conquer Online map set.
7. The exact Conquer Online client/region/version used as the parity baseline remains to be recorded. Different releases may add, remove, or change features.

## Reference and licensing research register
Use these for feature discovery and format research, not as blanket permission to copy or redistribute assets:
- Conquer Online community wiki: https://conquer-online.github.io/wiki/
- TQ Digital Games Archive: https://tqarchive.org/
- Public client preservation project (code license does not include game assets): https://github.com/deklol/Preservation-CO-Client
- ConquerToolsKit (inspect its repository license before reuse): https://github.com/darkfoxdeveloper/ConquerToolsKit
- Tiled2Dmap tools: https://github.com/SantasCode/Tiled2Dmap
- Community custom map collection (respect author attribution and stated terms): https://github.com/spiritedsnowcat/conquermaps
- Client map asset editing discussion: https://cooldown.dev/topic/10-client-how-to-edit-map-assets/

## Change control
- Update a row only with repository path(s), commit/test evidence, and the exact reference version or source used.
- Never upgrade PARTIAL/MISSING/BLOCKED to VERIFIED based on documentation alone.
- Keep excluded features explicit so they are not accidentally reintroduced.
- Do not modify existing GitHub Actions/workflow configuration as part of parity tracking.
- Review this matrix after every major feature batch and before release.
