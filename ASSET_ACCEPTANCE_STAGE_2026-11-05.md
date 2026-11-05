# Asset Acceptance Stage — 2026-11-05

## Decision

**Production asset acceptance remains BLOCKED / NOT APPROVED.** This stage is now tracked per playable class and per equipment/mount family. No aggregate model count, successful import, APK export, or scene startup can mark an asset approved.

## Source baseline actually inspected

- Source client: Conquer Online Mobile 1.1.2.3.
- Source archive SHA-256: `0d21a110c09b762ed5f1a5f4da022857b0534e489eb85052d15da460cb229d2a`.
- Version-matched members: 4,238.
- Itemtype inventory: 89 files, 57,940 unique numeric ID/name records; zero malformed or duplicate lines under the conservative ID/name parser. Positional fields remain opaque.
- Mount source files: `mountinfo.ini`, `mounttype.dat`, `dragon.ani`, `sdragon.ani`. Mount metadata is present, but exact mount model catalogue, body/tack/ornament assembly and animation mapping remain unresolved.
- Equipment source inventory: 102 files; includes weapon/armor transform and matching sources, itemtype records, helmet/armet references, socket/solidify tables and effect mappings. The exact item-to-model/texture/UV/attachment joins are not yet validated.
- Refinement sources: five binary DAT files are inventoried but not decoded.
- Gem sources: three files, including 52 parsed opaque INI sections; gameplay semantics remain unverified.
- Fashion sources: two files; suit data remains unresolved.

## Conversion and runtime evidence

- C3 conversion: 569 GLBs from 1,904 parsed records; 497 skipped and 40 parser failures. The output split is 24 character-category, 42 equipment, 1 monster, 4 world and 492 effect GLBs, plus 6 motion proof outputs. These are not 569 production-ready models.
- Character runtime PCK audit: 24 character-category GLBs loaded, but zero contained imported Skeleton3D nodes; zero complete class mappings were accepted.
- Mount runtime: 18 catalog entries are not 18 complete mount GLBs. The C3 conversion produced zero mount-category GLBs.
- Latest production visual CI gate (run 42115483129) correctly rejected primitive blockouts in Player.tscn, SimulatedPlayer.tscn and MainGame.tscn. The gate must remain active.
- Android 13 emulator launch succeeded far enough to install and keep the process alive for 45 seconds and capture two screenshots. The screenshot-comparison step then failed because that run's checked-out commit did not yet contain `tools/ci/compare_emulator_screens.py`; newer commits include the script. This is a test-harness path/version failure, not evidence of visual acceptance.

## Explicit per-family tracking

The machine-readable `quality/acceptance_registry.json` now separately tracks all 11 classes, mounts/riding, helmets/headgear, armor/body gear, weapons, fashion/capes/wings, paid/premium equipment, and mount tack/saddles/ornaments.

The validator requires six gates for any future ACCEPTED entry:
1. Source traceability and provenance.
2. Exact reference match.
3. Functional integration.
4. Runtime visual verification with retained evidence.
5. Automated tests.
6. Target-device performance evidence.

Paid/free classification must be decoded from the matching source data; it must never be guessed from IDs, names or folder placement.

## Required completion sequence

1. Decode and cross-check Mobile 1.1.2.3 item, mount, equipment, weapon, fashion, refinement and socket schemas. Keep unknown fields opaque.
2. Join source IDs to exact C3 objects, texture IDs/atlas regions, animation/motion records, effects and audio cues; report every unmatched record.
3. Complete the 11 class/gender body assemblies, skeleton and six-action coverage; export and verify all equipment socket transforms.
4. Convert and validate complete mount bodies, tack, ornaments, rider attachment, riding motion and mount-specific effects.
5. Produce per-item helmet, armor, weapon and paid-equipment front/back/side/close-up comparisons. Check UVs, normals, materials, clipping and z-fighting.
6. Replace primitive visible blockouts only after approved replacements are ready. Never hide or remove the fallback before a verified replacement is attached.
7. Capture the actual Android game at normal camera distance and close-up; then measure performance on Redmi Note 11 / Android 13.
8. Keep every item unresolved until source identity, rights, integration, visual review, automated tests and device evidence are complete.

## Current outcome

The acceptance ledger and CI enforcement were expanded and committed. The asset phase itself is **underway, not complete**. The current blocker is not a missing approval checkbox: the runtime package lacks complete rigged class models and converted mounts, while equipment mappings and per-item visual evidence remain incomplete. No model, mount, helmet, armor or paid item is promoted to final status by this report.
