# Character Body / Rig Mapping Audit — 2026-11-06

## Decision

**No class-to-body mapping is approved for runtime use by this audit.** The converted C3 body files are source-backed candidates, not verified class assignments. Do not populate `asset_role=complete_character` with `mapping_status=verified` from filename similarity, look number, mesh count, or a motion proof-of-concept alone.

## Evidence inspected

- GitHub Actions artifact: `C3-Model-Conversion-Reports`
- Artifact ID: `13463741706`
- Workflow run: `42131464090`
- Source conversion report: `reports/c3-conversion-report.json`
- Detailed model report: `reports/c3-model-audit.json`
- Motion import validation: `reports/c3-motion-poc-validation.json`
- Original C3 source root recorded by the report: `netdragon/c31/c3/`

The conversion report contains 569 converted records overall. The following 13 converted body files are present in the artifact:

| C3 body model | GLB output | Mesh chunks | Animated mesh chunks in static conversion |
|---|---|---:|---:|
| 7000000 | characters/c3/body/7000000.glb | 1 | 1 |
| 7101020 | characters/c3/body/7101020.glb | 18 | 17 |
| 7102000 | characters/c3/body/7102000.glb | 18 | 0 |
| 7103000 | characters/c3/body/7103000.glb | 18 | 17 |
| 7130000 | characters/c3/body/7130000.glb | 18 | 0 |
| 7131020 | characters/c3/body/7131020.glb | 18 | 17 |
| 7132000 | characters/c3/body/7132000.glb | 18 | 0 |
| 7133010 | characters/c3/body/7133010.glb | 18 | 17 |
| 7134010 | characters/c3/body/7134010.glb | 18 | 17 |
| 7135000 | characters/c3/body/7135000.glb | 18 | 17 |
| 8133010 | characters/c3/body/8133010.glb | 18 | 0 |
| 8134010 | characters/c3/body/8134010.glb | 18 | 17 |
| 8135000 | characters/c3/body/8135000.glb | 18 | 0 |

The 0/17 animated-chunk distinction is a conversion-report property; it is not evidence that the model is or is not a playable character. Some motion-only body sources were exported separately for the motion POC.

## Motion proof-of-concept results

The same artifact contains two Godot-import-validated skeletal motion samples:

- `look7_model7130000_weapon500_action100.glb`: one skeleton, 66 bones, one skinned mesh, 2,542 animation keys, 128 tracks.
- `look8_model8133010_weapon500_action100.glb`: one skeleton, 60 bones, one skinned mesh, 2,411 animation keys, 116 tracks.

The report marks both as `GODOT_SKELETON_VALIDATED`. Six VAT clips were also validated. This proves that these specific motion samples can be imported and that their animation data changes over time. It does **not** prove the corresponding body model belongs to a named class, that all actions are complete, or that the sample is ready for the player controller.

The broader motion-only report explicitly marks body/look pairings as `PATH_KEY_AND_BONE_SIGNATURE_CANDIDATES_ONLY_NOT_RUNTIME_PAIRED`. It reports 4,052 body/look candidate pairs and 558 motion-only documents. Those are search candidates, not 4,052 verified relationships.

## Existing mobile character-creation evidence

The checked-in `resource_stage/world/resource_mappings/mobile_character_creation_source.json` decodes 11 creation records from the supplied Mobile 1.1.2.3 source. Those records identify profession IDs and creation equipment IDs (armor, hair, weapons, head model), but explicitly do not provide verified Godot body meshes or skeleton mappings.

The two Thunderstriker creation records (profession IDs 20 and 22) remain distinct. Do not collapse them into one identity without reconciling the original role-selection source.

## Required joins before runtime approval

1. Resolve each selectable class and gender to the exact role/look key in the version-matched `rolechoose.ini`, `rolechoose_js.ini`, `selectcharacter.ini`, and `3dsimplerole.ini` sources.
2. Trace that role/look key to an exact `c3/body/<model-id>.c3` path. A numerical look resemblance alone is insufficient.
3. Pair each body with motion files using exact source path keys and a compatible bone signature; record the exact idle, walk, run, attack, hit, and death coverage available.
4. Verify the imported rig, skin bindings, material/texture bindings, scale, facing direction, and animation playback in Godot.
5. Capture front, side, back, and in-game camera screenshots for each class/gender. Review clipping and body proportions before marking the mapping verified.
6. Only then add a complete-character entry to the runtime catalog with explicit class, gender, source path, rig/motion references, evidence artifact, and reviewer status.

## Runtime safety

The current `CharacterModelMappingRules.gd` correctly accepts only entries with `asset_role=complete_character` and `mapping_status=verified`. Preserve that rule. The current mapping unit test uses synthetic test dictionaries; it proves the filter behavior, not that the production resource catalog contains verified class entries.

The current `LegendIntro.gd` intentionally blocks world entry while any selectable class lacks a verified complete-character mapping. This is why the app may remain at character selection after resource loading. Do not bypass that gate by assigning a body candidate to every class.

## Next concrete task

Continue source tracing from the exact Mobile role/look records to the C3 body path and motion path. Prioritize the already import-validated look 7 / model 7130000 and look 8 / model 8133010 samples for deeper source verification, but keep both at **POC / unassigned** until the exact class/gender join and in-game visual review are complete.


## Additional role-source trace (extraction artifact 13466315369)

The extracted source report contains structural metadata and decoded INI sections for the original Mobile 1.1.2.3 role files. It confirms:

- `rolechoose.ini` maps 18 UI slots to named role animation identifiers (for example `Role_FemaleTaoist`, `Role_MaleWarrior`, `Role_MaleDragonWarrior`, `Role_View_17`, and `Role_View_18`) and to profession/info indices.
- `selectcharacter.ini` labels slots 14–15 as Dragon-Warrior and slots 16–17 as Windwalker; its class descriptions establish the class identity but not the C3 body model path.
- `3dsimplerole.ini` contains `Role0`–`Role7` simple-object IDs 20001–20008 with standby/blaze motion IDs 9998800–9998871. It separately contains `Role100`–`Role115` entries with `Look` values 1–4 and armor/hair item IDs.
- The decoded creation table supplies profession IDs and equipment IDs, but its `sex_code` is -1 for these entries and does not give a body model ID.
- The report's `known_role_model_ids` list consists of the role-creation armor IDs and the `3dsimplerole.ini` armor IDs. It does not establish a body-model join.

**Important gap:** the role-animation names, simple-object IDs, look values 1–4, and C3 body filenames such as 7101020 / 7130000 / 8133010 are separate identifier families in the evidence collected so far. No direct key in this extraction report joins them. Treating the shared word “look” or a similar number as a body assignment would be guesswork.

The next source-tracing step is therefore to locate the original model/animation registry or binary resource index that maps the role-animation/simple-object IDs to concrete C3 body and motion paths. Until that registry is extracted and reconciled, the two skeletal POCs remain unassigned.


## Motion coverage correction from the raw validation JSON

A deeper read of `reports/c3-motion-poc-validation.json` confirms that the two skeletal imports are **standby/action 100 only**. The corresponding skeletal exports for walk/action 110 and run/action 120 were rejected by the exporter because their source bone matrices contain non-TRS shear (examples: look 7 bone 16 at frame 1; look 8 bone 21 at frame 11). Therefore the current skeletal POC does not provide a complete locomotion set.

The report also validates 72 VAT mesh-data entries across six clips (actions 100, 110, 120 for looks 7 and 8). These checks prove finite VAT data, changing frame positions, source vertex-order correspondence, and preservation of affine shear. They do **not** yet prove a Godot VAT shader/material is rendering the full character correctly at runtime, nor that the clip is performant on the target Redmi Note 11. The two paths must remain separate in the asset ledger:
- Skeletal: action 100 import validated; actions 110/120 rejected by current TRS exporter.
- VAT: data validated for 100/110/120; Godot runtime renderer and mobile performance not yet validated.

Do not describe either path as a complete playable animation set. The next technical work is to build a Godot VAT playback test scene using the exact exported metadata and textures, validate all body parts (including armet, weapons, limbs and pelvis) in sync, and profile it on Android hardware/emulator. In parallel, improve skeletal export to preserve affine/shear transforms or use a mathematically safe decomposition/bake route, then revalidate walk/run before adopting the skeletal path.
