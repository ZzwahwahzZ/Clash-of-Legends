# Published Resource Pack Audit Request

## Purpose
Inspect the exact 11 resource packs referenced by `RESOURCE_MANIFEST` from release `resource-packs-v4`. This request does not approve any model or texture by filename alone.

## Required evidence
- Verify every published pack's byte size and SHA-256 against `RESOURCE_MANIFEST`.
- Mount all packs in Godot 4.3 and inspect the runtime resource catalog.
- Enumerate character, equipment, mount, monster, animation, effect, map, interface, and audio resources.
- Record missing catalog paths, unreadable resources, renderable mesh counts, skeletons, animation clips, and material/surface availability.
- For character-class mappings, record exact asset path, class, gender, source identity metadata, mapping status, and available rig/animation evidence.
- For mounts, record exact item/mount identity metadata and distinguish verified mappings from candidates and unmapped files.
- Do not infer identity, equipment slot, class, gender, animation meaning, or visual approval from a filename alone.

## Acceptance rules
- A model is not approved solely because it imports or contains mesh surfaces.
- Character candidates require a usable skeletal rig, active materials, and non-empty idle and movement clips.
- Mount candidates require explicit item-to-model identity mapping and renderable materials.
- Missing evidence remains BLOCKED; never downgrade the gate or mark a candidate verified to make CI green.
- Keep the existing runtime visual visible when a replacement candidate fails validation.

## Output
Publish a machine-readable JSON audit report and a concise human-readable summary. Include exact pack totals, category counts, unmapped counts, and blockers. This audit is diagnostic; it does not by itself constitute visual acceptance.
