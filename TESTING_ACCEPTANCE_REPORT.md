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

- 563 converted C3 GLB scenes imported and passed geometry checks.
- 2,454 mesh surfaces, 936,015 triangles, and 709,677 vertices reported.
- 18,029 C3 MOTI chunks were parsed. The per-mesh exporter passed its Rust regression test and Godot import validation: 563 GLBs imported, 2,454 surfaces, 2,199 morph-capable mesh nodes, 503 animated models, 12,371 animation tracks, and 53,484 keys. 558 motion-only C3 documents remain unpaired to body models and may contain additional action clips.
- 1,060 PVR textures decoded with zero decoder failures.
- 40 C3 parser failures remain in effect paths because 4- or 8-byte tails are not understood by the pinned parser.
- Additional models were skipped when matching decoded PVR textures or renderable geometry were unavailable.

Conversion/import success is not equivalent to in-game model assignment, animation correctness, or visual parity.

## 4. Current resource-pack pipeline

Resource workflow: https://github.com/ZzwahwahzZ/Clash-of-Legends/actions/runs/41991454834

The full resource pipeline completed successfully in run https://github.com/ZzwahwahzZ/Clash-of-Legends/actions/runs/41991454834: 11 category PCKs exported, runtime PCK/model catalog validation passed, collision validation passed, and `RESOURCE_MANIFEST` with sizes/SHA-256 was committed. The packages total 1,414,091,280 bytes (about 1.317 GiB). The upload/release steps were skipped because the redistribution permission gate remains false; no PCK download URLs are published.

The explicit redistribution permission gate remains disabled. Do not publish original client assets or derivative copies publicly without separate rights clearance.

## 5. Acceptance decision

**Technical CI:** PASS for the checks listed above.  
**Gameplay source parity:** IN DEVELOPMENT.  
**Visual quality/parity:** NOT ACCEPTED.  
**Target-device verification:** NOT RUN.  
**Production release:** NOT APPROVED.

A feature remains open until its source provenance, actual runtime integration, rendered visual review, and applicable target-device evidence are present. Passing CI is necessary but not sufficient.
