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
- 497 models expose imported animation tracks; 18,029 motion tracks reported.
- 1,060 PVR textures decoded with zero decoder failures.
- 40 C3 parser failures remain in effect paths due to 4/8-byte unparsed tails.
- Further source models were skipped when their matching decoded PVR texture or renderable geometry was unavailable.

These results prove conversion/import, not class mapping, live-game attachment, rendered quality, or mobile performance.

## Packaging and distribution state

The Godot 4.3 category PCK builder, manifest generation, SHA-256 verification, and in-game resource downloader are implemented in the game repository. The current resource build run is:
https://github.com/ZzwahwahzZ/Clash-of-Legends/actions/runs/41991454834

At the time of this update, category PCK export was still running; runtime PCK validation and final manifest publication were pending. The explicit redistribution permission gate remains disabled. Do not publish original client assets or derivative copies publicly without separate rights clearance.

The game must keep resource distribution blocked until rights-cleared assets are identified. Private technical conversion and public redistribution are separate decisions.
