# Source Asset Inventory — Evidence Snapshot

**Source:** Source-Audit-Reports artifact from workflow run 42000137006  
**Source index:** 13,494 indexed file records  
**Source version used for the native client entries:** Conquer Online Mobile 1.1.2.3  
**Purpose:** establish what is actually present before building source-to-runtime mappings. This is an inventory, not an approval of assets or a claim of complete parity.

## Indexed resource categories

| Category | Indexed files |
|---|---:|
| Interface | 4,005 |
| Models | 3,634 |
| Maps | 3,232 |
| World/configuration | 1,304 |
| Effects | 557 |
| Audio | 323 |
| Characters | 176 |
| Equipment | 80 |
| Monsters | 77 |
| Animations | 58 |
| Mounts | 48 |
| **Total** | **13,494** |

## What the source index confirms

### Mounts
The index contains native-client references including `mountinfo.ini`, `mounttype.dat`, `dragon.ani`, `sdragon.ani`, and C3 mount effect paths. It also contains five GLB/OBJ pairs under `assets/triposr_42/`, with five corresponding previews. Those GLB/OBJ files are generated reconstructions; they are not verified native Conquer mount models. The current source C3 conversion audit produced zero mount-category outputs. Mount body models, tack, ornaments, motion, and per-mount IDs therefore remain unresolved.

### Equipment, weapons, helmets and armor
The index has 80 files in the equipment category, but only one generated Triposr GLB/OBJ equipment pair. It also indexes 89 native `itemtype*.ini` files and configuration/reference sources including `weapon_trans.ini`, `armor_trans.ini`, `weaponmatch.ini`, `weaponshow.ini`, `weaponmotiondata.dat`, `equiphole.ini`, `equipsolidify.ini`, `equiptreeinfo.ini`, `hundred_weapon(s).dat`, `phaseequip.dat`, `strengthdevelopequip.dat`, and `weaponsoulstory.dat`. These are valuable source records, but they do not yet establish a complete purchasable wardrobe or exact item-to-mesh/texture/UV mappings.

### Skills and effects
The source index includes skill-named OGG candidates, `magic.ani`, `magic1.ani`, `autousemagic.dat`, `3deffectinfo.ini`, `action3deffect.ini`, `actionlee3deffect.ini`, `weaponeffect.ini`, `weaponskillname.ini`, and `weaponskilllevelexp.ini`. A filename is not proof of which skill ID, class, rank, animation, projectile, VFX or sound it belongs to. No exact skill mapping is approved yet.

### Fashion and garments
The index includes `suittype.dat`, `wenzhang_suit_effect.ini`, and suit-on effects for lily, orchid, rose and tulip. This confirms reference/configuration material exists, not that every fashion item, garment model, texture and body attachment has been mapped.

### Gems and upgrade materials
The index includes `gemtip.ini`, `item_refine_attr.dat`, `item_refine_cost.dat`, `item_refine_upgrade.dat`, `item_refine_effect.dat`, and `item_refine_effect_ex.dat`, as well as socket/solidify configuration. Their record semantics, grades, recipes, consumption rules, success/failure behavior and resulting item appearance still require schema validation and cross-reference.

## Important source-to-runtime gaps

1. The 13,494 index rows are file inventory evidence only; counts do not prove semantic completeness.
2. The C3 WDB audit currently validates path indexes for `3DObj`, `3DTexture` and `3DSimpleObj`; other equipment tables remain schema-unverified.
3. `itemcfg.dat`, `copydrop.dat`, quest data and refinement visual-effect data have candidate decode probes, but the current reports explicitly reject them for runtime use until mobile-version schema and field semantics are validated.
4. The readable gem catalog preserves 52 sections from `gemtip.ini`, but key/value strings have not yet been promoted into gameplay mechanics.
5. The runtime skill list remains prototype data. Candidate audio/effect files must not be joined by filename similarity alone.
6. No paid/free classification is inferred from IDs, filenames, folders or category names.

## Next extraction and mapping sequence

1. Validate the exact 1.1.2.3 schemas for item, mount, weapon, armor, refine, gem and socket data against multiple independent records and source references.
2. Build stable registries preserving source file, line/record ID, checksum, version and confidence/status.
3. Join item records to C3 object IDs, texture IDs, model parts, motion and effect/audio references; report every unmatched record.
4. Build separate per-item visual reviews for helmets, armor, weapons, fashions, mounts and tack, including UV/atlas and material diagnostics.
5. Replace player, simulated-player and world blockouts only after the replacement assets have verified mappings and runtime evidence.
6. Keep all entries `UNRESOLVED — NOT APPROVED` until identity, implementation, visual comparison, runtime behavior and distribution rights are verified.

**Distribution note:** the inventory does not grant permission to redistribute proprietary Conquer assets. Reference use and shipment rights remain separate gates.

## Dedicated nested-APK audit results — 2026-11-05

The first CI pass exposed a packaging detail: the outer source archive contains the Android client as a nested APK. The audit was corrected to inspect that nested APK, and the corrected workflow completed successfully:

- Workflow: [Audit mobile gameplay source tables — run 42075363202](https://github.com/ZzwahwahzZ/Clash-of-Legends/actions/runs/42075363202)
- Commit: `93658671dc96f3dca5089bf12f2fa83712b81dda`
- Audit artifact: [Gameplay-Source-Table-Audit](https://github.com/ZzwahwahzZ/Clash-of-Legends/actions/runs/42075363202/artifacts/13438815306)
- Exact archive SHA-256: `0d21a110c09b762ed5f1a5f4da022857b0534e489eb85052d15da460cb229d2a`
- Version-matched source members indexed inside the nested client: 4,238.

The audit established a useful equipment-data baseline: **89 version-matched `itemtype*.ini` files containing 57,940 unique numeric record IDs and visible names, with zero malformed or duplicate lines** under the conservative ID/name parser. All remaining positional fields were retained as opaque; no gameplay meaning was guessed.

Target table observations:
- `gemtip.ini`: 52 INI sections parsed.
- `weaponeffect.ini`: 111 INI sections parsed.
- `actionlee3deffect.ini`: 8 INI sections parsed.
- `3deffectinfo.ini`: 3 INI sections parsed.
- `equiphole.ini`: 2 INI sections parsed.
- `mountinfo.ini`, `weaponskillname.ini`, `weaponskilllevelexp.ini`, several transform/matching files, and some fashion/socket INIs were present but did not pass the generic INI parser. They remain preserved as source files with hashes and explicit parse-failure status; their schema is not accepted.
- `mounttype.dat`, skill animation DAT files, and all five refinement DAT files were inventoried as binary/metadata-only. No field interpretation was attempted.

This gives us a much stronger ID/name inventory for the equipment family, but it does **not** yet establish item categories, paid status, exact models, helmet/armor texture regions, or a complete runtime wardrobe. The next safe step is to validate itemtype positional fields against independently readable source references and then join their IDs to the C3 object/texture index. The dedicated audit was also corrected to emit valid JSON and stream the archive checksum rather than loading the entire 842 MB archive into memory.

### Full itemtype ID/name export and armor-look candidate

A follow-up successful run [42076016258](https://github.com/ZzwahwahzZ/Clash-of-Legends/actions/runs/42076016258) now retains the full record-level ID/name catalogue in its private workflow artifact, rather than only samples. The report is valid JSON and includes all 57,940 itemtype records. For `itemtype13.ini`, all 3,638 records have 69 positional fields; column 59 is preserved as an **unlabelled candidate only**. Its observed values/counts are:

- `0`: 1,430 records
- `3000`: 456
- `3040`: 255
- `3010`: 249
- `3060`: 248
- `3050`: 248
- `3020`: 248
- `3030`: 248
- `3080`: 228
- `14040`: 14
- `3070`: 14

These values overlap some Look candidates already documented in the character-mapping research, but the column is deliberately not renamed to `Look` until its meaning is confirmed against the 1.1.2.3 client resolver. This is a promising cross-reference for armor/body model families, not yet an accepted model mapping.
