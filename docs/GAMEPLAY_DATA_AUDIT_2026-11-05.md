# Gameplay Data Parity Audit — 2026-11-05

## Scope and rule

This audit compares the current runtime gameplay scripts with the supplied Conquer Online Mobile source archive. It does not treat the older PC client schema as authoritative for the mobile APK. No item IDs, drop probabilities, quest requirements, refinement costs, or success rates may be inferred from an unrelated client build.

## Source findings

The source probe located these mobile files but did not decode them:

- `itemcfg.dat` — item definitions
- `copydrop.dat` — monster drop rules
- `questinfo.dat` (default, Spanish, and Arabic variants) — quest definitions
- `taskitem_info.dat` — quest item requirements
- `item_refine_effect.dat` and `item_refine_effect_ex.dat` — refinement visual effects
- `monster.dat` (language variants) — monster definitions

Their current status remains `PROBE_ONLY_NOT_PARSED`. The probe report contains source hashes plus a seed-9527 candidate output that now has strong structural signatures: `itemcfg.dat` resembles a Lua item table, `copydrop.dat` a Lua drop table, `questinfo.dat` and `taskitem_info.dat` Lua tables, and the two refinement files `@@`-delimited records. These remain candidate decryptions only; the report explicitly sets `accepted_as_mobile_format=false` because the seed/algorithm was borrowed from older PC-client research and has not yet been verified against the Android 1.1.2.3 reader.

Two readable source files were also found:

- `monstertype.ini` — visible `@@`-delimited monster rows. The new catalog builder names only the visible record ID and name and preserves all remaining columns as opaque values until a matching mobile schema is verified.
- `gemtip.ini` — readable INI sections and key/value strings. The new catalog builder preserves exact source keys and values without guessing item-ID mappings or converting display strings into gameplay formulas.

The external Conquer Online Development Wiki documents TQ File Cipher for particular older PC client patches, including patch 5517. That is a research lead only, not proof that the supplied Android 1.1.2.3 files use the same cipher or seed. The mobile APK's own reader/decoder or a successful signature-validated decode is required before applying it.

## Runtime gaps found in the current project

### Monster drops

`scripts/enemies/MonsterBase.gd` currently generates:
- random gold in the hard-coded 35–80 range;
- a hard-coded 25% equipment chance;
- a hard-coded 15% meteor chance;
- invented item records such as `refined_blade` and `meteor_stone`.

These values are not linked to decoded `copydrop.dat` records. They are provisional gameplay placeholders and must not be accepted as reference parity.

### Inventory and refinement

`scripts/player/PlayerInventory.gd` currently seeds invented starter values, including potion healing/mana amounts, meteor quantities, and starter weapon stats. Its refinement preview also hard-codes success chances, gold-cost progression, meteor consumption, and stat increments. Additional perfection, blessing, enchant, purification, and anima rules likewise contain local constants without decoded mobile source provenance.

These features can remain available for development testing, but their status must remain unaccepted until the mobile source records are decoded and the rules are replaced or verified against them.

### Auto-loot categories

`scripts/automation/AutoLootManager.gd` groups gems and quest items under the generic materials toggle. This may not match the original mobile filter semantics. The UI/filter mapping needs comparison against the original client behavior before acceptance.

## Latest CI catalog and candidate diagnostics

The completed resource run `41991454834` produced:
- `monstertype.ini`: 738 unique readable records, 0 malformed/duplicate lines.
- `gemtip.ini`: 52 readable sections, exact keys/values preserved without inferred gameplay effects.
- Candidate `copydrop.dat`: 981 drop groups and 53 unique `dropItemTypeID` values under the seed-9527 probe.
- Candidate `itemcfg.dat`: 18,771 indexed item entries.
- Candidate quest file: 3 top-level Lua tables and 341 keyed entries; task-item candidate has 10 rows.
- Candidate refinement tables: 648 base rows and 240 extended rows.

Cross-checks are incomplete: only 160 of 981 candidate drop-group IDs overlap the 738 IDs in the readable `monstertype.ini` catalog, and only 14 of 53 unique candidate drop item IDs overlap the 18,771 `itemcfg.dat` IDs. These mismatches may reflect distinct namespaces, missing companion tables, or a wrong client-version/cipher assumption. Do not import the candidate values into runtime until the Android reader/cipher is verified and the cross-references are explained.

## Changes made in this phase

- Added `tools/resource_packs/build_gameplay_reference_catalog.py`.
- Added a workflow step to generate provenance-preserving catalogs from readable mobile `monstertype.ini` and `gemtip.ini` sources.
- The generated report records exact source paths, SHA-256 hashes, record/section counts, and blocked encrypted sources.
- Opaque fields remain opaque; no guessed field names or gameplay values are exported into runtime systems.

## Required next work

1. Completed: verify the catalog-generation step in CI and inspect the generated JSON/report; preserve the source hashes and opaque fields.
2. Identify the actual encryption/encoding used by the supplied Android 1.1.2.3 APK by examining its client reader code or validating the candidate decoder against known plaintext signatures and cross-file relationships. Do not assume the PC patch 5517 cipher applies.
3. Decode item, drop, quest, task-item, monster, and refinement records with source hashes and record-level provenance.
4. Cross-link item IDs, monster IDs, drop groups, quest requirements, materials, refinement requirements, and visual effect IDs.
5. Replace provisional runtime constants with the decoded source-backed catalog.
6. Add deterministic tests for every cross-reference and edge case, then verify the systems in Godot scenes and on the Redmi Note 11.

## Acceptance decision

Items/inventory, monster drops, quests/materials, refinement rules/effects, and auto-loot behavior remain `IN_DEVELOPMENT`. None is accepted by this audit. Successful PCK export or script execution is not visual or functional parity evidence.
