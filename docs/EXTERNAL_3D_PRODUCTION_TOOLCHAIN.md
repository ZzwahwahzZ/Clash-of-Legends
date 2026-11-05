# External 3D Production Toolchain

**Updated:** 2026-11-05  
**Purpose:** Use specialist tools outside GitHub to create and validate production-ready assets, then bring approved outputs into the existing Godot 4.3 project. GitHub remains the source-control, build, audit, and packaging host; it is not the 3D authoring tool.

## Decisions

### 1. Preserve original C3 skinning data before attempting auto-rigging

The current C3-to-GLB exporter emits per-mesh morph targets from sampled vertex positions. This is useful as a diagnostic preview, but it is not skeletal skinning and must not be accepted as a finished character rig. The source PHY vertices contain two bone indices and two weights; the source MOTI tracks contain per-bone matrices. A correct production converter must preserve both influences and build a glTF `skin`, `JOINTS_0`, `WEIGHTS_0`, inverse-bind matrices, joint nodes, and bone-transform animation channels.

The source bone hierarchy/rest-pose semantics and matrix conventions must be established from controlled reference renders before shipping. Do not invent parent relationships or assume that bone-count equality proves a correct rig. Do not discard the second vertex influence.

### 2. External tools and their roles

| Tool | Role | Acceptance / limitation |
|---|---|---|
| [Blender](https://www.blender.org/) | Primary external authoring, mesh cleanup, material/UV work, rig inspection, animation review, and glTF export | Use headless Blender in CI for deterministic conversions where possible. Keep editable source files outside runtime packages. |
| [C3Studio](https://github.com/abdouthematrix/C3Studio) | Independent Windows C3 asset browser and animation viewer; useful to inspect source part names, per-mesh MOTI bindings, and source playback | Viewer/reference implementation, not assumed to be a production GLB exporter. Its source is Apache-2.0; review its license and notices before reuse. |
| [Rigger](https://github.com/asu37/Rigger) | Blender GPL-3.0+ auto-rigging, skin binding, motion retargeting, and game-engine export | Use for original replacement meshes or source assets proven to lack usable skinning. Do not replace valid source C3 weights with guessed weights. Verify addon compatibility and output in Godot. |
| [Godot 4.3 glTF importer](https://docs.godotengine.org/en/4.3/tutorials/assets_pipeline/available_formats.html) | Runtime target for GLB scenes, skeletons, skins, and animation libraries | GLB is the delivery format. Validate imported Skeleton3D, Skin binds, bone names/rests, AnimationPlayer clips, and actual playback. |
| [Godot skeleton retargeting](https://docs.godotengine.org/en/4.x/tutorials/assets_pipeline/retargeting_3d_skeletons.html) | Retarget compatible humanoid animation libraries | Bone names alone are insufficient: bone rest transforms must also match. Use reviewed BoneMap/SkeletonProfile data. |

### 3. Privacy and rights

- Prefer local/headless Blender and open-source tools in a controlled runner.
- Do not upload proprietary source-client assets to third-party cloud rigging services unless the user explicitly authorizes that transfer and redistribution rights are separately established.
- Every shipped asset must carry source URL, author, license, attribution, checksum, and conversion provenance.
- Technical access to a source archive is not permission to redistribute its assets.
- Use independently licensed or original replacement art where source redistribution rights are unclear.

## Production pipeline

1. **Inspect:** select representative male/female humanoid bodies, monsters, mounts, and equipment. Inspect C3 source in C3Studio and the existing parser; record PHY/MOTI slot names, bone counts, influence ranges, frame keys, texture slots, and transforms.
2. **Prove one rig:** build one male and one female test character from source C3 data. Preserve both vertex influences. Establish the source bind pose, bone transforms, matrix order, coordinate conversion, and inverse-bind matrices against the reference viewer.
3. **Convert:** emit real glTF skins and joint animation channels. Keep morph-target diagnostics separate from production skeletal GLBs.
4. **Retarget:** create reviewed humanoid profiles for compatible class bodies. Use Rigger/Rigify for original meshes or creatures only when source skin data is unavailable or unusable.
5. **Assemble:** attach head, hair, armor, helmet, weapon, cape, mount and accessories through named sockets/part transforms; verify both genders and equipment combinations.
6. **Create world art:** author/repair terrain, architecture, props, collision, navigation, LODs, materials, lighting and VFX in Blender or purpose-built open asset tools; import the results as GLB/GLTF or suitable Godot resources.
7. **Validate in Godot 4.3:** import and instantiate the GLBs, inspect Skeleton3D/Skin data, play every required clip, render front/side/back and motion frames, detect bounds/collision issues, then run the Android emulator.
8. **Package:** only after visual and rights gates pass, merge approved outputs into the existing resource catalog and PCK pipeline.

## Mandatory skeletal acceptance gates

A production character is rejected unless all checks pass:

- At least one real `Skeleton3D` and one glTF `skin` exist; a morph-only model is not a substitute.
- Every skinned mesh has valid `JOINTS_0` and normalized `WEIGHTS_0`; all positive-weight joint indices resolve.
- Both source influences are retained where present; no silent first-influence-only truncation.
- Inverse-bind matrices and rest pose produce the correct neutral pose.
- Idle, walk, run, attack, skill, hit, and death clips (where applicable) animate the intended bones.
- No detached limbs, exploding vertices, twisted bind pose, floating equipment, or body/weapon socket drift in sampled frames.
- Male and female rigs are validated independently; do not reuse a slot order across incompatible signatures.
- Godot 4.3 import succeeds and runtime playback is observed in a rendered scene.
- Android 13 emulator evidence is captured from the actual game. A successful export or parser test alone is not visual acceptance.

## Current status

- Existing C3 parser/exporter and external-motion proof-of-concept are useful foundations.
- Current production GLB path is morph-target animation, not a complete skeletal-skinning pipeline.
- C3Studio and Rigger have been identified as external tools with distinct roles; neither is being misrepresented as an already-integrated fix.
- The first production milestone is a verified male/female skeletal GLB pair from the original C3 source, followed by an in-engine rendered animation test.
- Existing primitive player scenes remain temporary and must be replaced before the visual quality gate can pass.
