# CLASH OF LEGENDS — VISUAL IMPLEMENTATION & ACCEPTANCE REPORT
**Updated:** 2026-11-05  
**Engine:** Godot 4.3  
**Target:** Redmi Note 11 / Android 13 / ARM64-v8a  
**Acceptance status:** **NOT VISUALLY ACCEPTED — INTERNAL DEVELOPMENT BUILD ONLY**

## 1. Current decision

The project has made measurable progress in C3 conversion and external motion import, but the game is not visually complete, not device-verified, and not ready for production release.

A successful build, a GLB import, or animation tracks in a headless test do not prove correct poses, correct class identity, professional materials, equipment attachment, clipping-free assembly, or visual parity with Conquer Online Mobile.

## 2. Latest verified technical evidence

### Android/Godot build
- Latest successful build/test workflow: [41999396225](https://github.com/ZzwahwahzZ/Clash-of-Legends/actions/runs/41999396225)
- Signed ARM64 debug APK exported and signature-verified.
- Package: `com.zwahwahzz.clashoflegends`
- Minimum API 21; target API 34; CI compatibility check includes Android 13 / API 33.
- APK size: 36,342,142 bytes.
- This is an internal debug build, not a production game and not proof of real-device performance.

### Original C3 conversion and external-motion proof of concept
- Latest C3 audit and import run: [41999396204](https://github.com/ZzwahwahzZ/Clash-of-Legends/actions/runs/41999396204)
- 1,944 C3 files found; 1,904 parsed; 40 parser failures remain, all in effect paths with unparsed 4- or 8-byte tails.
- 8,340 meshes, 709,677 vertices, 936,015 triangles, and 18,029 MOTI chunks were reported.
- 569 GLBs imported and passed the current geometry/morph/animation validator: 2,562 surfaces, 2,307 morph-capable mesh nodes, 509 animated models, 13,163 animation tracks, and 57,012 keys.
- 1,060 PVR textures decoded with zero decoder failures. 497 C3 models were skipped when required renderable geometry or matching decoded texture data was unavailable.

### Motion-only C3 research and POC
- 558 motion-only C3 documents were found; 537 have a parsed numeric look/weapon/action path key.
- A coarse bone-count-only comparison yields 82,440 possible pairs and is explicitly **not** accepted as a mapping.
- Exact ordered PHY/MOTI signatures plus numeric look-family matching narrow the report to 11 look-7 and 4 look-8 body candidates. These are structural candidates, not verified class identities.
- Six audit-only clips (action tokens 100/110/120, weapon token 500) were applied to look-7/look-8 body candidates and imported by Godot 4.3. Each imported with 18 MeshInstance3D nodes, 18 surfaces and 18 morph-capable meshes. Per clip: action 100 had 198 tracks / 918 keys; action 110 had 126 / 558; action 120 had 72 / 288.
- The POC outputs remain under `build/c3-glb/motion-poc`, outside runtime PCK category folders. This validates the conversion/import path only; it does not prove correct in-game poses, action naming, class mapping, or visual quality.

### WDB/DBC source investigation
- A metadata-only parser for the original `c3.wdb` container was added to the source-staging pipeline. It indexes DBC table names, formats, counts and selected records without publishing the original DBC blobs.
- The full source/resource workflow is rerunning under [42000137006](https://github.com/ZzwahwahzZ/Clash-of-Legends/actions/runs/42000137006); the compact WDB metadata artifact is pending completion.

## 3. Current character and world gaps

- `PlayerController.gd` no longer chooses a character model by array index. It now requires explicit metadata: `asset_role=complete_character`, `mapping_status=verified`, exact class, and requested gender. No class-specific complete-character mapping has yet been accepted, so this is a safety gate against unrelated GLBs—not a finished character-selection system.
- Look 7/8 gender interpretation and class-to-body IDs remain candidates pending WDB cross-checks.
- Body socket names such as `v_armet`, `v_l_weapon`, `v_r_weapon`, `v_back`, `v_pelvis` and `v_zero` have been identified, but their attachment transforms are not yet exported and runtime-verified.
- Head, hair, armor, weapon, mount, cape and wing assembly is not complete. No clipping/intersection acceptance has been performed.
- `SimulatedPlayer.tscn` still contains simple box-based meshes and is not a final character asset.
- `MainGame.tscn` still contains procedural blockout architecture/terrain, not an accepted reconstruction of the original mobile maps.
- Wolf, dragon, NPC, player and world scenes still contain procedural geometry. Structural hierarchy checks do not establish professional visual quality.
- No side-by-side rendered screenshots have been reviewed against the approved mobile reference.
- No Redmi Note 11 measurements exist yet for FPS, memory, heat, loading time, or stability.

## 4. Resource distribution and rights status

- Historical resource build: [41991454834](https://github.com/ZzwahwahzZ/Clash-of-Legends/actions/runs/41991454834) completed 11 category PCK builds and runtime/model catalog checks; historical package total was 1,414,091,280 bytes (about 1.317 GiB).
- The current explicit redistribution gate is disabled for new publication. However, the existing public release tag `resource-packs-v4` already exposes 11 PCK assets, including `models.pck` and `world.pck`. The current gate does not retract that older public release.
- Do not publish additional original client assets or derivative copies without separate rights clearance. The WDB audit output is metadata-only.

## 5. Required work before visual acceptance

1. Finish the WDB/DBC report and use its `3dobj`, `3dtexture`, `3dmotion` and `weaponmotion` mappings to prove class, model, equipment and action links.
2. Replace all procedural/box blockouts with approved, correctly scaled production assets.
3. Export and verify socket transforms; assemble head, hair, armor, weapons, mounts, wings and capes with clipping/intersection checks.
4. Validate the six external-motion POCs visually, then expand the action library and integrate it into the live character controller.
5. Resolve the 40 remaining effect-path C3 parser failures and review the 497 skipped models.
6. Convert and render the original mobile maps, including terrain, height, object placement, collision, portals and camera.
7. Produce in-game rendered captures and compare them side-by-side with the mobile reference.
8. Install and measure on Redmi Note 11 / Android 13.

**Release decision:** INTERNAL / PARITY NOT ACCEPTED. No production-ready or visual-parity claim is authorized by the current tests.
