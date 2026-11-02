# FOUR-PACKAGE RECOVERY: SOURCE FINDINGS AND BUILD ROUTE
**Date:** 2026-11-02  
**Repository:** Clash-of-Legends / main  
**Decision:** Do not import or redistribute proprietary Conquer Online client payloads without a documented grant. Use public archives for historical/reference research only, and create the shipped game assets from original or properly licensed sources.

## Executive result

The public research located official historical Conquer Online installers/patches and open-source tools that explain or inspect their formats. It did **not** locate four ready-made, redistributable PCK bundles matching this project's planned package names. A public installer or a map/model/audio viewer is not equivalent to an authorized asset pack.

| Planned package | What can be obtained now | What is not obtained / cannot be shipped on current evidence | Build route for Clash of Legends |
|---|---|---|---|
| `world_twin_city.pck` (target ~711.27 MiB) | Public DMAP format documentation; open-source DMAP/Tiled conversion tools; public historical client archives for reference; some community-created maps exist with author-specific conditions | No verified clean-room Twin City package at the target size; no blanket redistribution permission for official client maps/textures | Build original Twin City scene/map using project-native geometry/materials; use DMAP tools only for lawful reference or user-authorized local conversion; create our own collision/nav/minimap and landmarks |
| `creatures_and_bosses.pck` (~652.50 MiB) | Public documentation for Monster.dat/MonsterType.dat and community reverse-engineering notes; project already has sample WildWolf and BossDragon scenes; Hunyuan3D 2.1 generation notebook is present | No verified, licensed ready-made Conquer model/animation bundle found; archived client models remain proprietary unless rights say otherwise | Generate original GLB creature/boss models through the existing Hunyuan3D pipeline; create rig/animations/materials/VFX in the project; validate every GLB before import |
| `classes_and_gear.pck` (~570.67 MiB) | Public ItemType.dat, item-ID, equipment-slot, gem/socket and hero-renderer documentation; project has an existing player/equipment prototype and weapon glow shader | No verified, redistributable class/armor/weapon model bundle found; official client meshes/textures and extracted data are not automatically reusable | Build a reference-derived data catalogue from documented mechanics; generate original class silhouettes, weapons, armor and fashion GLBs; author item stats and upgrade/socket tables independently |
| `audio_and_vfx.pck` (~459.76 MiB) | Project has a weapon glow shader and some existing visual effects; public format documentation helps identify effect/motion concepts | No licensed Conquer soundtrack/SFX/VFX bundle found; no verified audio package is currently present | Generate original VFX in Godot shaders/particles; source audio from explicitly licensed libraries or create original audio; record license and attribution per file |

**Important:** target sizes are planning estimates from the existing resource manifest, not evidence that those bytes exist or that every pack must be exactly that size. Final package sizes must be based on actual optimized content. Do not pad files to hit target sizes.

## Sources found

### 1) Official historical client archive — reference only
- TQ Digital Games Archive: https://tqarchive.org/
- Archive entry for Conquer Online v5517: https://archive.org/details/conquer-online-v5517
- The archive describes itself as an index of publicly/free-available official files and lists many historical ENZF client builds/patches. The v5517 Archive.org item is an installer of about 438.5 MB, not four separated PCKs.
- **Use:** identify a reference client/version and, if the owner chooses, inspect a personally obtained client locally for private compatibility research subject to applicable terms.
- **Do not:** copy its client payload into this game's distributable packages or publish extracted assets without explicit rights.

### 2) Map format and tooling
- Conquer Online Development Wiki — DMAP: https://conquer-online.github.io/wiki/files/formats/dmap.html
- GameMap.dat format: https://conquer-online.github.io/wiki/files/content/gamemap.dat.html
- Tiled2Dmap (public source): https://github.com/SantasCode/Tiled2Dmap
- DMapGodot importer (Godot 4.4 plugin; compatibility with this Godot 4.3 project must be checked before adoption): https://github.com/shekohex/DMapGodot
- Community maps: https://github.com/spiritedsnowcat/conquermaps and https://github.com/flickerstop/conquerMaps
- Community map repositories have author-specific conditions/attribution; no blanket commercial or redistribution license was established in this review. Treat them as **license review**, not approved assets.
- **Use:** learn DMAP structure, inspect geometry/layers, and build an original Godot map pipeline. Do not assume source-code license grants rights to the map content.

### 3) Creature and equipment data formats
- Monster.dat: https://conquer-online.github.io/wiki/files/content/monster.dat.html
- MonsterType.dat: https://conquer-online.github.io/wiki/files/content/monstertype.dat.html
- ItemType.dat: https://conquer-online.github.io/wiki/files/content/itemtype.dat.html
- Mount type reference: https://conquer-online.github.io/wiki/files/content/mounttype.dat.html
- Item IDs and equipment structure can inform a compatible *new* data model. Documentation is not a grant to copy proprietary data tables wholesale.

### 4) Existing project generation route
- Hunyuan3D 2.1 Kaggle notebook: `tools/ai-asset-generation/hunyuan3d_2_1_kaggle_dual_t4_clash_of_legends.ipynb`
- Existing model weights are attached by the owner in Kaggle; the notebook preflight previously reported both Tesla T4 GPUs and the attached weights dataset as available.
- Output dataset previously configured by the owner: https://huggingface.co/datasets/ZzwahwahzZ/clash-of-legends-assets
- This assistant cannot operate the owner's Kaggle/Hugging Face account or see its private run output through the connected GitHub repository. Do not claim a model was generated until the owner supplies a run result or output file.
- The Hunyuan3D 2.1 license conditions must be followed for generated output and distribution; keep model provenance with each generated asset.

## Work we can complete without waiting for proprietary packages

1. Create original environment assets for the current Twin City blockout and expand map coverage.
2. Generate original monsters, bosses, player gear and mounts using the existing Hunyuan3D notebook, then rig/animate and import.
3. Create original VFX with Godot particles/shaders and procure audio under explicit licenses.
4. Replace planned package sizes/hashes with actual values after content is assembled; build package archives only from validated files.
5. Add a first-launch installer only after there are real package URLs and a signed release manifest. It must resume safely, verify exact byte count + SHA-256, install atomically, and then allow full airplane-mode play.

## Exact owner-side input needed to unblock the remaining asset acquisition

The only part this assistant cannot perform from the connected repository tools is running the owner's Kaggle notebook and accessing its generated private dataset. When a batch is generated, export/download the resulting GLB files (or share a public read-only dataset link) and provide the asset list/run log. Never send the HF token. If the owner has a legally obtained Conquer client, it may be used locally as a reference; do not upload proprietary client archives or extracted assets unless the owner has confirmed permission for that use and distribution.

## Gate before calling any pack complete

- Source and license/provenance recorded for every included file.
- Real files exist; no placeholders and no fabricated sizes.
- GLB/audio/texture files open and validate.
- Godot import succeeds and in-game scene references resolve.
- Package archive has real SHA-256 and exact byte size.
- Download/install path validates the package and survives interruption.
- Final Android build passes an airplane-mode gameplay test after initial setup.
