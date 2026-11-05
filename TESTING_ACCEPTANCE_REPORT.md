# Testing Acceptance Report

## Latest verified state — 2026-11-05

- **Android/Godot CI:** run [41999396225](https://github.com/ZzwahwahzZ/Clash-of-Legends/actions/runs/41999396225) passed. The ARM64 Android debug APK was exported and signature-verified; artifact size is 36,342,142 bytes. This is a technical debug build, not a production release.
- **Gameplay/scene tests:** 102/102 gameplay tests, 7/7 structural geometry checks, 3/3 physics-shape checks, 7 destination checks, and the current auto-loot/collision checks passed in CI. These verify internal behavior only, not source parity.
- **C3 external-motion POC:** run [42000129691](https://github.com/ZzwahwahzZ/Clash-of-Legends/actions/runs/42000129691) passed. It produced 569 GLBs including six audit-only external-motion clips. Godot imported all six clips; each has 18 mesh nodes, 18 surfaces and 18 morph-capable meshes. Action 100 imported 198 tracks/918 keys per clip, action 110 imported 126/558, and action 120 imported 72/288.
- **C3 source audit:** 1,944 C3 files found; 1,904 parsed; 40 still fail; 8,340 meshes; 709,677 vertices; 936,015 triangles; 18,029 MOTI chunks. The dedicated [C3 motion POC validation report](https://github.com/ZzwahwahzZ/Clash-of-Legends/actions/runs/42000129691) records 6/6 clips as GODOT_IMPORT_VALIDATED. These remain conversion/import experiments, not accepted in-game animations.
- **Motion-only mapping:** 558 motion-only documents found; 537 have a parsed numeric look/weapon/action path key. Ordered bone signatures and look-family matching produce candidate sets only; the 82,440 broad bone-signature pairs are intentionally not treated as valid assignments.
- **WDB/DBC:** a metadata-only parser was added for the original `c3.wdb` container. Its audit step passed in the source-staging workflow, and the current full run [42000137006](https://github.com/ZzwahwahzZ/Clash-of-Legends/actions/runs/42000137006) is rerunning the pipeline to publish the compact metadata report. No original DBC blobs are included in that report.
- **Device testing:** no real Redmi Note 11 installation, FPS, memory, thermal, loading-time or long-session stability capture has been performed.

The sections below retain earlier test history; the latest results and corrections above supersede older counts and statements where they differ.

# TESTING & TECHNICAL VALIDATION REPORT
**Game:** Clash of Legends (صراع الأساطير)  
**Updated:** 2026-11-05  
**Engine:** Godot 4.3  
**Latest successful run:** https://github.com/ZzwahwahzZ/Clash-of-Legends/actions/runs/41991982657  
**Status:** TECHNICAL CI PASS — GAMEPLAY PARITY AND VISUAL ACCEPTANCE NOT ESTABLISHED

## 1. Latest automated evidence

The latest successful CI run completed these checks:

| Check | Result | What it proves |
|---|---:|---|
| Gameplay test runner | 102/102 passed | Current scripted prototype logic satisfies its own test assertions |
| Structural visual/geometry audit | 7/7 passed | Selected scene parts exist and have non-empty mesh surfaces/bounds |
| Auto-loot filter audit | Passed | Gold, equipment, gem, and quest filter toggles are wired |
| Physics shape audit | 3/3 scenes passed | Player, wolf, and dragon scenes have enabled collision shapes |
| Runtime Player/WildWolf collision | Passed | Player movement stops at the wolf collider in the test scene |
| World travel audit | 7 destinations passed | Manual/quest teleport and invalid-destination rejection work |
| React Studio build | Passed | Studio frontend builds in CI |
| Android export | Passed | Signed ARM64 debug APK exported and verified for Android 13 compatibility |

The Android artifact is an internal debug build, not a production release. It is approximately 36.3 MB and does not prove that final resource packs are installed or that the full game content is complete.

## 2. Important limitations of the tests

- The 102 tests verify current implementation behavior; they do not prove that the values match the supplied Conquer Online Mobile source.
- Inventory/refinement tests still exercise provisional constants such as starter stats, meteor consumption, refinement costs, and success rates. A passing test means the prototype is internally consistent, not that those values are correct.
- Monster drop probabilities and loot values remain invented/provisional until `copydrop.dat` and related mobile source data are decoded.
- The 7 visual checks are structural geometry checks, not a rendered visual-quality review. They do not prove proportions, material quality, texture alignment, clipping, class identity, or correct equipment attachments.
- Godot headless logs still show renderer warnings involving null mesh references during scene teardown. They remain open for diagnosis.
- No side-by-side rendered comparison against the mobile reference has been accepted.
- No installation, FPS, memory, thermal, loading-time, or stability measurements have been performed on the Redmi Note 11 itself.
- PCK validation reported these category counts: characters 223, monsters 78, maps 5,069, equipment 124, mounts 48, effects 1,168, animations 58, interface 5,523, audio 323, models 3,634, world 1,309. It also reported 172/172 structurally valid model scenes and 96 converted C3 GLB models catalogued in the checked non-effect runtime categories. The old 15/172 AnimationPlayer count is not accepted as proof of working per-mesh animation; the stricter animation validator is now under CI.

## 3. Original asset conversion evidence

C3 audit run: https://github.com/ZzwahwahzZ/Clash-of-Legends/actions/runs/41991461493

- 569 converted C3 GLB scenes (including six audit-only external-motion POCs) imported and passed geometry checks.
- 2,562 mesh surfaces, 936,015 triangles, and 709,677 vertices reported.
- 18,029 C3 MOTI chunks were parsed. The per-mesh exporter passed its Rust regression test and Godot import validation: 569 GLBs imported, 2,562 surfaces, 2,307 morph-capable mesh nodes, 509 animated models, 13,163 animation tracks, and 57,012 keys. 558 motion-only C3 documents were analyzed; 537 expose numeric look/weapon/action path keys. Six proof-of-concept clips were applied to look-7/look-8 candidate bodies and imported by Godot. Full class/action assignment remains open.
- 1,060 PVR textures decoded with zero decoder failures.
- 40 C3 parser failures remain in effect paths because 4- or 8-byte tails are not understood by the pinned parser.
- Additional models were skipped when matching decoded PVR textures or renderable geometry were unavailable.

Conversion/import success is not equivalent to in-game model assignment, animation correctness, or visual parity.

## 4. Current resource-pack pipeline

Resource workflow: https://github.com/ZzwahwahzZ/Clash-of-Legends/actions/runs/41991454834

The full resource pipeline completed successfully in run https://github.com/ZzwahwahzZ/Clash-of-Legends/actions/runs/41991454834: 11 category PCKs exported, runtime PCK/model catalog validation passed, collision validation passed, and `RESOURCE_MANIFEST` with sizes/SHA-256 was committed. The historical package build total was 1,414,091,280 bytes (about 1.317 GiB); the currently public v4 release contains 11 PCK assets. The upload/release steps in that historical build were skipped because the redistribution permission gate was false. However, the existing public release tag resource-packs-v4 already exposes 11 PCK assets, including models.pck and world.pck. The current gate prevents new publication but does not retract that older public release.

The explicit redistribution permission gate remains disabled for new publication. Existing public release resource-packs-v4 remains downloadable; do not publish additional original client assets or derivative copies without separate rights clearance.

## 5. Acceptance decision

**Technical CI:** PASS for the checks listed above.  
**Gameplay source parity:** IN DEVELOPMENT.  
**Visual quality/parity:** NOT ACCEPTED.  
**Target-device verification:** NOT RUN.  
**Production release:** NOT APPROVED.

A feature remains open until its source provenance, actual runtime integration, rendered visual review, and applicable target-device evidence are present. Passing CI is necessary but not sufficient.
