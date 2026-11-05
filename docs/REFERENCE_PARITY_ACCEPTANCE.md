# Reference Parity Acceptance Standard

This project uses Conquer Online Mobile as the approved gameplay and presentation reference. It is not a license to copy or redistribute third-party assets. The game remains an independently named and implemented project.

## Non-negotiable release rule

A feature is **not complete because it runs**. It remains `IN_PROGRESS` or `REFERENCE_NOT_VERIFIED` until its behavior and presentation have been checked against an identified Conquer Online Mobile reference and the original source data available to this project.

Never replace an unavailable original behavior with invented values, colors, probabilities, item mappings, animations, or placeholder geometry and then mark it complete.

## Required evidence for each feature

Every feature audit must record:

1. **Reference identity** — exact mobile client/version or supplied source package, screen/scene, and reference capture or source file.
2. **Source provenance** — source filename, SHA-256, record/key/offset where applicable, parser version, and whether the value is decoded or merely probed.
3. **Functional parity** — inputs, outputs, state transitions, costs, requirements, rates, and edge cases verified against source/reference.
4. **Visual parity** — side-by-side reference and in-game captures at comparable camera, scale, lighting, UI state, and equipment/refinement level.
5. **Runtime integrity** — no missing resources, placeholder meshes, broken attachment points, clipping, unintended intersections, or contradictory UI/system state.
6. **Performance** — measured target-device results on Redmi Note 11 / Android 13; desktop CI is not a substitute.
7. **Test evidence** — automated test output plus manual visual/runtime review where required.

## Status vocabulary

- `SOURCE_PROBED`: file located and metadata/strings inspected; schema and records are not decoded.
- `SOURCE_DECODED`: schema parser decoded records with provenance and validation.
- `IMPLEMENTED_UNVERIFIED`: code exists but parity is not demonstrated.
- `FUNCTIONALLY_VERIFIED`: source-backed behavior and automated tests pass.
- `VISUALLY_VERIFIED`: comparable in-game capture reviewed against the reference.
- `DEVICE_VERIFIED`: tested on the target Redmi device with measured performance.
- `ACCEPTED`: all required evidence for that feature is present.
- `BLOCKED_SOURCE_OR_REFERENCE`: exact source/reference is unavailable; do not fabricate a substitute.

## Specific acceptance gates

### Items, monster drops, quests, and upgrades
Do not publish live item/drop/quest tables until item IDs, monster IDs, drop associations, probabilities, quest requirements, and upgrade costs are decoded from source records and cross-validated. Each item must retain its source provenance. Generic random drops are not parity.

### Refinement visuals
Do not infer the original glow from broad color bands. Decode the original refinement effect tables, map each effect to its item/equipment conditions and refinement level, and verify in rendered scenes against reference captures. A shader existing or being assigned is not visual acceptance.

### Characters and equipment
Verify the actual mesh, scale, skeleton/bone attachment, animation compatibility, weapon visibility, and all equipment slots. A model importing successfully is not proof that it looks or animates correctly in-game.

### Maps and world
Verify original map identity, terrain dimensions/heights, object placement, collision, transitions, NPC/monster placement, and camera presentation. Parsed map cells or exported GLBs alone do not prove a playable faithful map.

### Interface, audio, and animation
Verify the mobile UI layout and interaction states, Arabic RTL adaptation without changing the reference behavior, audio cue mapping, and animation/event timing. Presence of source files alone is not acceptance.

## Current known limitations (must remain visible until resolved)

- Gameplay binary files have been located and probed, but the probe report explicitly says `PROBE_ONLY_NOT_PARSED`; do not treat sampled strings as decoded game data.
- The current weapon glow implementation is provisional and is not verified against the original refinement effect tables or rendered reference captures.
- Current map scene still contains procedural blockout elements; do not mark those areas visually accepted.
- Equipment attachment to the imported character skeleton is not yet proven.
- CI validation and PCK export do not prove visual parity or Redmi Note 11 performance.

## Review checklist

A reviewer may accept a feature only when all applicable evidence is attached to its audit record. Missing evidence means the feature stays open. Do not downgrade this standard to meet a release date.
