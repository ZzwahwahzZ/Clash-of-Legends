# External Reconstruction Candidate Audit — 2026-11-06

## Decision

**All 42 TripoSR reconstructions remain REFERENCE / RECONSTRUCTION CANDIDATES. None is approved as a production replacement.**

The source repository is `ZzwahwahzZ/Conquer-Mobile-Assets.` (note the final period in the repository name). Its README describes it as an archive of original Conquer Online Mobile reference images. The 3D outputs in `assets/triposr_42/` and `generated_models/` are image-to-3D reconstructions, not extracted native game models.

## Inventory confirmed from the source repository

| Family | Source images | TripoSR GLB outputs | Finding |
|---|---:|---:|---|
| Characters | 20 | 20 | Candidates only; no source-to-class mapping or complete rigged character proof |
| Mounts | 5 | 5 | Candidates only; no mount ID, rider socket, tack, or riding-motion proof |
| Equipment | 1 | 1 | One broad reference candidate; not a per-item helmet/armor/weapon library |
| Maps | 5 | 5 | Reference geometry candidates; not traversable production maps |
| Monsters | 11 | 11 | Reconstruction candidates; no source identity/rig/action proof |
| **Total** | **42** | **42** | **No production approvals** |

The generation reports record successful mesh reconstruction for the 42 files. That status means a mesh was generated; it does not establish source fidelity, rigging, animation, UV/material quality, gameplay attachment, or target-device performance.

## Mount geometry triage

The repository's own `previews/triposr_42/geometry_audit.csv` records these mount results:

| Candidate | Vertices | Faces | Connected components | Watertight | Degenerate faces |
|---|---:|---:|---:|---|---:|
| mounts_0001 | 84,935 | 169,328 | 67 | No | 5 |
| mounts_0002 | 54,731 | 109,268 | 1 | No | 0 |
| mounts_0003 | 4,304 | 8,581 | 5 | No | 0 |
| mounts_0004 | 61,584 | 122,924 | 25 | No | 9 |
| mounts_0005 | 37,476 | 74,812 | 15 | No | 2 |

These results identify repair work, not automatic rejection of every surface: open topology can be valid for layered game meshes, but the high component counts and degenerate faces require inspection. In particular, mounts_0001 and mounts_0004 have substantial disconnected-component counts and should not be attached to a rider before mesh-island, hidden-interior, normal, and silhouette review.

## Source-image quality and traceability

- The source collection report records 42 images: 20 character, 5 map, 5 mount, 1 equipment, and 11 monster references.
- The five mount source images are individually indexed in `original_images/sources_manifest.csv` with source URL, dimensions, format, and SHA-256.
- Mount reference image dimensions range from 373×591 to 1280×720. The smallest source has limited detail; the large images provide more detail but still represent a single view, not complete turnarounds.
- The collection report points to the Mobile mount-system guide page: https://comobile.99.com/guide/info/classes/2023-02-14/status_-_mount_system.shtml
- Source-image collection is not proof of permission to redistribute the images or derivative meshes. Keep the existing distribution/rights gate unchanged.

## Why these candidates cannot replace current blockouts yet

1. The reports establish generated GLB/OBJ geometry, but do not provide evidence of a valid armature, skin weights, riding idle/move clips, or rider attachment transforms.
2. A single reference image cannot establish hidden-side anatomy, underside geometry, saddle placement, leg clearance, or exact 360-degree appearance.
3. Geometry audit marks all five mount outputs non-watertight; several have multiple disconnected components and some degenerate faces.
4. The current asset pipeline's C3 conversion report still has zero complete mount-category GLBs. These five image-to-3D outputs are a separate candidate source and must not be misreported as successful native C3 mount conversion.
5. No Android in-game screenshots or Redmi Note 11 performance measurements exist for these candidates.

## Next repair sequence

1. Inspect each GLB's scene graph, mesh count, material slots, UV sets, normals, transforms, and any skeleton/animation data.
2. Compare the GLB silhouette against its exact indexed Mobile reference image; reject mismatched reconstructions.
3. Repair disconnected/degenerate geometry only where visual inspection shows it is defective; preserve legitimate separate armor/tack pieces.
4. Rebuild missing hidden-side geometry and saddle/tack details from additional version-matched references, not invented guesses.
5. Rig only after the correct mount body is established; create and test rider seat/hand/foot attachment points and riding motion.
6. Keep every candidate outside the production catalog until it passes source traceability, reference match, functional integration, runtime visual review, automated checks, and target-device performance.

## Reproducible source paths

- GLB/OBJ reconstructions: `assets/triposr_42/mounts_0001_*.glb` through `mounts_0005_*.glb`, with corresponding OBJ files.
- Source images: `original_images/mounts/`.
- Geometry evidence: `previews/triposr_42/geometry_audit.csv`.
- Generation evidence: `assets/triposr_42/generation_report.csv` and `generated_models/generation_report.csv`.
- Source URL/hash inventory: `original_images/sources_manifest.csv`.

**Acceptance status remains BLOCKED / NOT APPROVED.** The audit adds five traceable mount reconstruction candidates to the repair queue; it does not change any production asset status.

## External repair-tool research (2026-11-06)

### Blender is the selected repair/inspection host for the five GLBs

- Blender's official remeshing guidance explains that voxel remesh can eliminate internal/self-intersecting geometry, but explicitly warns that voxel remesh is not suitable for final deforming character topology. Therefore this pipeline does **not** blindly voxel-remesh mounts or characters; it uses a conservative BMesh pass and preserves disconnected components for visual review. Source: https://docs.blender.org/manual/en/dev/modeling/meshes/retopology.html
- Blender's official support page points to the maintained manual, developer docs, Python API, Blender Studio training, and Blender Stack Exchange for troubleshooting: https://www.blender.org/support/
- The official TripoSR guidance confirms that single-view reconstructions infer unseen backs and concavities and are less reliable for thin, transparent, and reflective structures. This is why the current one-view mount candidates cannot be accepted as complete models. Source: https://triposr.org/docs/image-to-3d
- The upstream TripoSR research repository documents a GPU-heavy single-image reconstruction pipeline and its install/runtime constraints. Source: https://github.com/VAST-AI-Research/TripoSR

### C3 Operator: useful, but not a universal fix

The external C3 Operator 2.3.1 Blender add-on supports C3 model import/export and weapon export. Its own README says it was tested on garments, and lists unresolved scale/orientation normalization, bone-system translation, UV conversion, and hair/effect support. Its workaround for the `required argument is not a float` error is applying transformations and merging near-duplicate vertices by distance. This is useful for diagnosing original C3 conversion failures, but it is not evidence that it can correctly rig or export the AI-generated mount GLBs. Source: https://github.com/Tachyon-S/C3-Operator

### Rigging reference

The Roblox Creator Hub Blender rigging guides are used only as general technical references for armature binding, automatic weights, and pose testing—not as a compatible game rig. They emphasize testing the deformations after binding and correcting weights when necessary:
- https://create.roblox.com/docs/art/modeling/rig-a-simple-mesh
- https://create.roblox.com/docs/art/modeling/skin-a-simple-mesh

### New automated candidate-repair path

Added `tools/external_assets/repair_mount_glbs.py` and `.github/workflows/external-mount-repair.yml`. The workflow downloads the five source GLBs and their indexed source images from the external asset archive, runs Blender BMesh inspection, applies only near-coincident vertex welding and degenerate-edge cleanup, recalculates face normals, exports separate repair candidates, and emits before/after component/topology metrics. It deliberately does not delete disconnected islands or overwrite original files.

**Important:** A successful Blender run only validates that the toolchain imported, inspected, and re-exported the files. It does not visually approve them. The resulting candidates remain blocked until image-to-model silhouette comparison, texture/material review, underside/back inspection, rider-saddle attachment, rigging, riding animation, and in-game performance tests pass.
