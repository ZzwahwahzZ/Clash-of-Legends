# Asset source audit
**Updated:** 2026-11-05

The project owner account contains a separate source repository: https://github.com/ZzwahwahzZ/Conquer-Mobile-Assets.

A read-only recursive Git tree inspection found 42 GLB/OBJ reconstruction candidates: 20 characters, 5 map references, 5 mounts, 1 equipment reference, and 11 monsters. The repository also includes previews, source images, reports, and UV/vertex-color experiments.

The source repository publishes an extracted archive (842,723,106 bytes; SHA-256 0d21a110c09b762ed5f1a5f4da022857b0534e489eb85052d15da460cb229d2a), a prepared archive (108,387,746 bytes; SHA-256 18c6a3f4461fb01827436466c3af18ec782cf5555793c7ac32a198030db75c26), and a supplemental archive (435,948,386 bytes; SHA-256 28233860b864efc0fc5a9181c18ca2f0ee9a4c4f3441a689b3c9f5f91d34f7f7). These are source-release metadata values, not independently rehashed by this audit note.

The earlier 42-model geometry report marks models as rendered but reports watertight=false for every model. UV projection was demonstrated on only 3 character models and was explicitly a test, not production PBR texturing. Rigging, skinning, animation clips, complete traversable maps, and a full equipment wardrobe were not established by those reports. Treat these generated assets as reconstruction candidates, not finished production assets.

## Current C3/PVR conversion evidence

The original C3 audit workflow completed successfully on 2026-11-05:
https://github.com/ZzwahwahzZ/Clash-of-Legends/actions/runs/41991461493

- 563 C3-to-GLB scenes imported and passed geometry checks.
- 2,454 mesh surfaces; 936,015 triangles; 709,677 vertices.
- 18,029 C3 MOTI chunks were parsed. The per-mesh exporter now uses the MOTI chunk matching each PHY mesh. CI passed: 563 GLBs imported, 2,454 surfaces, 2,199 morph-capable mesh nodes, 503 animated models, 12,371 animation tracks, and 53,484 keys. 558 motion-only C3 documents still require pairing to body models for additional action clips.
- 1,060 PVR textures decoded with zero decoder failures.
- 40 C3 parser failures remain in effect paths due to 4/8-byte unparsed tails.
- Further source models were skipped when their matching decoded PVR texture or renderable geometry was unavailable.

These results prove geometry conversion/import, not class mapping, live-game attachment, animation correctness, rendered quality, or mobile performance.

## Packaging and distribution state

The Godot 4.3 category PCK builder, manifest generation, SHA-256 verification, and in-game resource downloader are implemented in the game repository. The current resource build run is:
https://github.com/ZzwahwahzZ/Clash-of-Legends/actions/runs/41991454834

The resource workflow completed successfully: 11 category PCKs were exported and passed PCK runtime/model-catalog validation. Their combined size is 1,414,091,280 bytes (about 1.317 GiB). The generated `RESOURCE_MANIFEST` records exact sizes and SHA-256 hashes for all 11 packages.

The manifest status is `BUILT_NOT_PUBLISHED_REVIEW_REQUIRED`; `distribution_allowed` is false and every `download_url` is empty. The PCK artifact upload and GitHub release publication were intentionally skipped by the explicit redistribution gate. The packages exist only in the completed CI build workspace and are not currently downloadable by the game. Do not publish original client assets or derivative copies publicly without separate rights clearance.

The game must keep resource distribution blocked until rights-cleared assets are identified. Private technical conversion and public redistribution are separate decisions.

## Full source processing results (2026-11-05)

- 13,494 unique supported files staged (1,250,494,111 bytes) across 11 categories.
- TPI/TPD extraction: 7,461 unique files; 0 failed entries; 9 multi-block entries reconstructed; 1 empty source placeholder.
- MJP: 3,355 of 3,358 decoded to PNG; 3 rejected because the header did not match the current decoder.
- PVR: 1,373 of 1,376 decoded to PNG; 3 failures.
- DMap: 209 of 209 parsed; 0 failed; 37,924,892 terrain cells; 411 game-map catalog records.
- C3: 707 GLB models converted; 69 parser failures (all in effect paths); 638 skipped due missing matching decoded texture or renderable geometry.

The package build and structural validation are complete, but the above unresolved source records and the unverified visual/model mappings remain open.
## 2026-11-05 follow-up: C3 WDB and publication status

The source index contains the original mobile `c3.wdb` at:

`resource_stage/world/apk_assets/ConquerOnline-1.1.2.3/assets/ConquerRes/ini/c3.wdb`

- Size: 19,734,073 bytes
- SHA-256: `5e2412beb9000d38578f88f7ba68ce17c17448f376d13e8fd5f36d9234a35f80`
- Header sample: `BDMG`
- Header table offset: 19,731,721
- WDB table entry count: 28

A metadata-only WDB/DBC parser was added at `tools/resource_packs/audit_c3_wdb.py`. Its source-staging audit step passed in workflow run `42000137006`; the full workflow is still processing C3 conversion, DMap validation and PCK checks before it uploads the compact report. It does not place original DBC blobs in the report or public resource packs.

**Publication correction:** the current workflow gate blocks new PCK publication when `ALLOW_C3_ASSET_REDISTRIBUTION` is false, but the existing public release tag `resource-packs-v4` already exposes 11 PCK assets, including `models.pck` and `world.pck`. The gate does not retract that historical release. No release deletion or access change has been made.


## 2026-11-05 live audit of the currently published PCK release

Workflow run: https://github.com/ZzwahwahzZ/Clash-of-Legends/actions/runs/42080338561  
Audit request: ASSET_REFERENCE_LIBRARY/PUBLISHED_RESOURCE_PACK_AUDIT_REQUEST.md

The exact 11 PCK files listed in the current RESOURCE_MANIFEST all mounted successfully in Godot 4.3. The runtime scan of the mounted package contents reported:

- 1,946 original .c3 files, 1,511 .pvr files, 1,468 .dat files, 1,474 .ini files, 246 .scene files, 209 .dmap files, and 85 .ani files.
- Zero .glb/.gltf model files found anywhere in the mounted runtime resource set.
- Zero renderable GLB models, zero imported skeletons, and zero imported animation clips in that package set.
- The runtime catalog expected by AssetCatalog.gd, res://resource_stage/world/resource_catalog.json, is absent. No alternative resource_catalog.json was found among the package JSON files; the JSON files present are source previews/reports and client configuration.

The resource-pack audit therefore failed correctly at the missing runtime catalog check. This is not a Godot import failure and must not be "fixed" by weakening the audit. It proves that the published PCK release currently mounted by the game contains the original C3/PVR/DAT source inventory, but not the converted GLB runtime catalog required by AssetCatalog. The prior 563/707 C3-to-GLB conversion results were produced in separate audit/build workspaces and are not evidence that those GLBs are included in these published PCKs.

Runtime consequence: the class-model lookup cannot resolve a verified runtime character model from these PCKs; the player keeps the existing fallback scene. The mount model lookup likewise has no verified runtime catalog to bind an equipped mount to its exact model. The recent runtime safety changes deliberately refuse arbitrary array-index selection and preserve the current visible model when a verified candidate is unavailable.

Required next step: rebuild the runtime resource packages from a reviewed, rights-cleared asset bundle that includes the converted model outputs and generated catalog, then rerun the full PCK mount/catalog/identity/rig/material/animation audit. Do not copy the currently published source PCKs into a new release or expose proprietary source assets publicly as a shortcut.
