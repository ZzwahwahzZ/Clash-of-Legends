# CANONICAL CONQUER ONLINE MOBILE REFERENCE LOCK

**Project:** Clash of Legends (صراع الأساطير)  
**Decision:** Owner-approved canonical reference snapshot  
**Decision date:** 2026-11-04  
**Status:** LOCKED AS THE PROJECT'S PRIMARY MOBILE REFERENCE

## 1. Canonical source selected by the owner

The owner explicitly approved the Conquer Online Mobile client resources already supplied and extracted in the project's asset workflow as the final reference baseline for feature research and comparison.

- Source asset repository: https://github.com/ZzwahwahzZ/Conquer-Mobile-Assets.
- Extraction release: https://github.com/ZzwahwahzZ/Conquer-Mobile-Assets./releases/tag/mobile-extracted-assets
- Canonical extracted archive: `extracted-assets-001.zip`
- Archive size: `842,723,106` bytes
- SHA-256: `0d21a110c09b762ed5f1a5f4da022857b0534e489eb85052d15da460cb229d2a`
- Inventory recorded for this archive: 314 entries (174 3D-model entries, 90 image/texture entries, 25 other entries, 25 game-data/config entries).

## 2. Version/build identification — do not fabricate

The owner's approval locks the supplied mobile client snapshot as the canonical project reference. It does **not** by itself prove a marketing version, region, release date, APK versionName/versionCode, or internal build number.

Until those identifiers are recovered from original client metadata/APK manifests or other reliable evidence:
- Refer to it as **Owner-approved Conquer Online Mobile supplied client snapshot**.
- Record the exact version/build as **UNIDENTIFIED / pending metadata verification**.
- Do not label it "latest", "classic edition", or a numbered release without evidence.
- Do not silently mix features from unrelated PC clients, other mobile builds, regional variants, or fan-maintained servers into the baseline.

## 3. Feature-research rules

1. Inspect the supplied client files, game data, configuration, UI resources, audio, maps, models, textures, and other extracted resources for evidence of systems and content.
2. Treat absence from the extracted archive as inconclusive: a feature may be server-driven, downloaded later, encoded, or absent from this partial extraction.
3. Build a traceable feature catalogue. Every feature record must include its evidence source (file/path, observed UI, or corroborating reference), confidence, and whether it is confirmed, inferred, unresolved, or excluded.
4. Research additional evidence only to resolve gaps in this exact mobile reference. Clearly label evidence from other builds and never silently promote it to canonical status.
5. Record all discovered main quests, side quests, repeatable quests, class/progression quests, daily/weekly/event quests, prerequisites, branches, objectives, NPCs, dialogue, turn-in conditions, and rewards. Do not reduce the quest system to a kill counter or a short sample chain.
6. Keep the owner's implementation constraints in force: original Clash of Legends identity; offline local gameplay; Gold-only economy; no real players, network chat, matchmaking, or real-money/premium purchase paths. Translate multiplayer-dependent activities into local deterministic simulations rather than deleting their gameplay purpose.
7. Use original or properly licensed implementation assets and content. The reference is for research and feature/experience mapping; this lock does not grant redistribution rights to proprietary client assets, code, text, music, or other copyrighted material.

## 4. Acceptance rule

A system is not considered complete because a screen, placeholder, stub, isolated script, or data record exists. It must be implemented, connected to relevant systems, tested through its full lifecycle, saved/restored offline where applicable, and supported by acceptance evidence.

## 5. Next required verification

- Inspect the original source archives and extracted metadata for APK/client version identifiers.
- Cross-check the existing feature parity matrix against the canonical snapshot.
- Expand the quest catalogue and all system inventories from evidence.
- Mark each feature as confirmed, inferred, unresolved, owner-adapted, or out of scope, with evidence references.
- Only then convert the catalogue into implementation tickets and test cases.
