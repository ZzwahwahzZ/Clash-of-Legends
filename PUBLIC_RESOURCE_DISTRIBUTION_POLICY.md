# Public Resource Distribution Policy

## Current release boundary

The downloadable resource release is restricted to the explicit allowlist in `distribution/OWNED_ASSETS_ALLOWLIST.json`.

Currently allowlisted:
- `assets/shaders/weapon_glow.gdshader` — project-original shader implementation.

Excluded from public downloadable PCK releases:
- `resource_stage/**` and all generated source-derived resource packs.
- Extracted Conquer Mobile audio, models, textures, maps, effects, and their converted GLB/PVR derivatives.
- Any source-derived item, monster, quest, or drop data whose redistribution rights or mobile schema have not been established.

## Build and integrity

The public release workflow builds an owned-only Godot PCK, validates that Godot can mount it, and generates `RESOURCE_MANIFEST` with the exact byte size and SHA-256. The Android resource downloader accepts only the configured release tag and verifies both size and SHA-256 before mounting a downloaded package.

The 11 source-derived PCKs remain internal build outputs. Their build success is not permission to redistribute them.

## Existing repository exposure

The public main branch previously contained 298 extracted OGG files under `assets/audio/extracted/`. A `.gitignore` rule now prevents them from being re-added after removal, but this rule does not untrack files already committed and does not erase earlier Git history. Those files are not included in the new owned-only resource release. A separate reviewed cleanup is still needed to remove already-tracked files from the current branch; historical Git objects would require a separate history rewrite.
