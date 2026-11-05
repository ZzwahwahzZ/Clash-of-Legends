# Paid Equipment & Mounts — Visual Fidelity Acceptance Gate

**Status: BLOCKED / NOT APPROVED**  
**Applies to:** every paid/premium weapon, armor piece, helmet, garment, fashion, mount, mount saddle/tack/ornament, and attached visual effect.

## Non-negotiable visual target

For these categories, the approved in-game asset must preserve the exact Conquer Online Mobile source appearance: model silhouette and proportions, geometry details, engravings, pattern placement, colors, texture artwork, material response, transparency, ornament placement, and distinctive effects. No redesign, recolor, simplification, generic replacement, or “close enough” substitute is permitted.

Technical work may improve import reliability, UV correctness, normal handling, material setup, mipmapping, lighting calibration, and runtime performance only when those changes do not alter the source identity or visible design.

## Acceptance is per item, not per category

An item can be marked `APPROVED` only when all of the following are present:

1. **Identity and provenance:** stable item/model ID; category; exact original source path; source version; source checksum; ownership/permission and intended-use record.
2. **Geometry:** complete expected mesh/part inventory; no missing helmet crest, armor plate, weapon fitting, mount tack, or ornament; no broken normals, gaps, clipping, z-fighting, or unintended deformation.
3. **Texture assignment:** each mesh/part is mapped to the correct source texture and texture region; UV coordinates and atlas rows are checked; no stretched, mirrored, offset, bleeding, or repeated fragments; original palette and pattern remain unchanged.
4. **Material behavior:** opaque/alpha parts, alpha cutoff/blending, vertex color, double-sided surfaces, roughness/metallic response, and mip levels are checked against the source.
5. **Visual comparison:** source and in-game render are compared at equivalent angles and scale (front, back, both sides, and close-up details). Screenshots and reviewer notes are retained.
6. **Runtime check:** inspect at normal gameplay camera distance and close-up, under neutral and gameplay lighting, including animation/equipment attachment where relevant.
7. **Rights gate:** the exact source may ship only when the project's rights/permission cover that distribution. A private technical conversion is not permission to publish proprietary files.

Missing evidence means `UNRESOLVED — NOT APPROVED`, never implicit approval.

## Current C3/PVR pipeline evidence (2026-11-05)

Latest verified CI run: [Audit original C3 models — run 42071562646](https://github.com/ZzwahwahzZ/Clash-of-Legends/actions/runs/42071562646)  
Commit: `90a002d4459a4e6c67d5659fc1c2eccb3c559876`  
Artifact: [C3-Model-Conversion-Reports](https://github.com/ZzwahwahzZ/Clash-of-Legends/actions/runs/42071562646/artifacts/13435852656)

- Godot import/validation and the render step both completed successfully.
- The audit report records 1,904 source model records, 569 converted outputs, 497 skipped records, and 40 parser failures (the failures are in effect paths).
- The 569 converted outputs are categorized as: 492 effects, 42 equipment, 24 characters, 4 world assets, 1 monster, and 6 motion proof outputs.
- 1,060 PVR textures decoded with zero decoder failures in this C3 audit.
- Six male/female Idle, Walk, and Run VAT proof clips validated; 72 deforming VAT mesh records were validated, with no missing expected clips.

**These results prove a technical conversion/import path and selected animation proofs. They do not prove premium item identity, complete equipment coverage, texture-to-mesh correctness, visual parity, or production art quality.**

## Matching mobile source-index evidence

A separate metadata-only audit of the same Conquer Online 1.1.2.3 source set located `ini/c3.wdb` (SHA-256 `5e2412beb9000d38578f88f7ba68ce17c17448f376d13e8fd5f36d9234a35f80`). It parsed the C3 object-path index (`3DObj.dbc`: 3,316 records) and the simple-object composition table (`3DSimpleObj.dbc`: 797 records). It also detected 25,405 weapon records, 3,041 armet records, 1,376 mount records, and 53,254 3D texture records, but the current audit only records those tables' headers/counts where their record layouts are not yet validated. **These counts are not a verified paid-item catalogue and do not yet map shop entries to exact visual assets.**

The source-index audit report is available in [Source-Audit-Reports run 42000137006](https://github.com/ZzwahwahzZ/Clash-of-Legends/actions/runs/42000137006). The next data task is to safely decode and validate the relevant item-table schemas, then cross-reference their IDs with the C3 object/texture and mount records before any visual approval.

## Explicit gaps found in this audit

- No mount-category C3 output was produced in this audit (`mounts/c3` count: 0). Mounts and their tack/ornaments remain unresolved here.
- The 42 equipment outputs are not a complete purchasable wardrobe. The report contains a limited set of `armet`, `hair`, `head`, and `weapon` paths; it does not establish the complete set of armor, garments, fashions, weapon tiers, or paid item IDs.
- The current conversion report does not contain a per-item source-to-render visual comparison or a verified mapping from paid shop entries to C3 model/texture IDs.
- The current renderer/exporter proof is not a substitute for reviewing atlas UV placement, hard-edged helmet/armor texture artifacts, material response, and small ornamental details on each actual item.

## Next required work before character or item approval

1. Build a source-backed item registry from the matching mobile-version item/shop data and source asset index. Record paid status only when supported by the matching version's data; do not infer it from a model ID.
2. Join every registry entry to its exact model, texture(s), attachment point, and effects. Keep unmatched entries in an explicit missing-assets report.
3. Produce per-item texture/UV diagnostic renders and turntable/contact sheets. Include helmet and armor close-ups because sharp streaking, atlas bleeding, and incorrect mesh-to-texture assignment are known review concerns.
4. Correct the mapping/import issue at source. Do not paint over, recolor, or otherwise hide a mismatch.
5. Repeat source-vs-runtime visual checks and retain evidence before changing an item to `APPROVED`.

## Status vocabulary

- `SOURCE_VERIFIED`: original source file and provenance are identified.
- `CONVERTED_TECHNICALLY`: parser/exporter/importer accepted the asset.
- `VISUAL_REVIEW_REQUIRED`: geometry, UV, texture, material, or comparison checks remain.
- `UNRESOLVED — NOT APPROVED`: exact source, mapping, permission, or visual evidence is missing.
- `APPROVED`: every per-item acceptance check above passed and evidence is retained.

No category-wide approval is permitted from aggregate counts alone.

## Runtime scene audit — 2026-11-05 (latest checked main)

The production visual gate was executed in workflow run [42072303327](https://github.com/ZzwahwahzZ/Clash-of-Legends/actions/runs/42072303327). Android 13 signed APK export and the Android 13 emulator smoke test passed, but the Godot validation job failed at the production visual gate. The exact reported failures were:

- scenes/characters/Player.tscn: placeholder BoxMesh, CylinderMesh, and SphereMesh render geometry.
- scenes/characters/SimulatedPlayer.tscn: placeholder BoxMesh and SphereMesh render geometry.
- scenes/core/MainGame.tscn: placeholder BoxMesh, CylinderMesh, and PrismMesh render geometry.

Code inspection confirms these are not merely false-positive resource names: Player.tscn constructs its torso, head, helmet, pauldrons, limbs, sword, shield, horse body and saddle from primitive meshes. MainGame.tscn constructs its ground, plaza, gate, furnace, lava, trees and terrain props from primitive meshes. SimulatedPlayer.tscn likewise builds its body, head, limbs and weapon from primitive meshes.

The current player importer can instantiate a catalog model only when an explicit reviewed class mapping exists. If the mapping is absent, it returns without importing a model; the primitive scene children remain visible. The mount importer currently requests the first entry in the mounts category rather than resolving a source-verified mount identity. This is not an acceptable per-mount mapping and must be replaced by stable source IDs and reviewed attachment metadata.

The current C3 audit contains 569 converted outputs, but only 42 equipment outputs and zero mount-category outputs. Motion pairing also remains incomplete: the audit lists 558 motion-only documents, but the recorded pairing status is candidate paths/bone signatures only, not runtime-paired clips. These outputs therefore cannot yet be treated as a complete playable character wardrobe or mount library.

The current GameContentDatabase.gd contains a hand-authored sample skill dictionary, while CombatEngine.gd labels its local skill entries as prototype entries. These values are not a source-verified skill catalogue. They must not be presented as exact reference mechanics or used to approve skill parity.

### Required implementation order

1. Decode and validate the item/model/texture/mount table schemas against the exact 1.1.2.3 source files; preserve raw source IDs, file paths and hashes in a machine-readable provenance registry.
2. Resolve complete character body/look/weapon/motion combinations, then implement source-verified character assembly and equipment attachment points. Remove primitive visible character parts only when the replacement asset and rig are verified; never leave an invisible or broken player as a workaround.
3. Resolve every helmet and armor piece to its exact geometry, texture atlas region, UVs, material flags and attachment/bone. Generate front/back/side and close-up runtime comparisons for each entry.
4. Build separate registries for weapon families, paid equipment, fashion layers, starter and collectible mounts, and mount tack/ornaments. Do not infer that a record is paid from its numeric ID.
5. Replace the hand-authored sample skill list with source-verified skill records, including class/branch eligibility, rank progression, costs, cooldowns, target rules, animation/motion, effect/projectile, VFX and audio links. Unknown fields remain explicitly unresolved.
6. Decode the refinement, socket, gem and crafting/material tables only after their schemas are validated; link every grade, icon, recipe, consumption rule, outcome and resulting equipment appearance to source evidence.
7. Replace the primitive world scene with verified world/map assets and data, including correct object composition, texture assignment, collision and navigation. A decorative scene assembled from generic shapes is not an acceptable substitute.
8. Run source-to-runtime visual review and Android 13 device-class performance checks. Keep the production visual gate failing until the three critical scenes use approved production assets and all required comparisons pass.

**Current acceptance status:** character visuals BLOCKED / NOT APPROVED; simulated-player visuals BLOCKED / NOT APPROVED; main world visuals BLOCKED / NOT APPROVED; mounts UNRESOLVED / NOT APPROVED; exact skill catalogue UNRESOLVED / NOT APPROVED; complete paid-item wardrobe UNRESOLVED / NOT APPROVED. Passing APK export or emulator startup does not change these statuses.
