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

## 2. Version/build identification — verified Android package metadata

The base APK was recovered from the owner-supplied archive and its Android manifest was decoded and validated. The canonical reference is now identified as:

- Android package: `com.Tq.CQ2ClientAndroid`
- `versionName`: `1.1.2.3`
- `versionCode`: `123`
- Base APK: `ConquerOnline/ConquerOnline-1.1.2.3.apk`
- APK size: `155,612,867` bytes
- APK SHA-256: `b1b8ccf0d5e1a9dcf346f8f11c20011cd9c68332f1b92676e79f87290f12c8f2`
- Manifest minSdk: `21`; targetSdk: `35`

The Android package version is verified. The server-side content revision, region-specific differences, and any post-install content updates are still not identified. Do not label this client "latest" or mix unrelated PC clients, mobile builds, regions, or fan-maintained servers into the canonical baseline.

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


## 6. Source-release metadata observed on 2026-11-04

A live GitHub API inspection of the `mobile-source-files` release returned eight currently listed loose resources:

| File | Bytes | SHA-256 |
|---|---:|---|
| `autoupdate.ini` | 23 | `9e6039dc8d7c1caa33068d822b1032a144a7d531fd31093228b68acf3dcad9d8` |
| `autoupdate.dat` | 969 | `22adc23de1fef9cefbe815cb20458f43aab608c0f833b5e5bd8657389e39d4f1` |
| `updateres.ini` | 1,672 | `9a2935c90d362d4a41f2b0abe2ec6918727680de709a40f671964d252771cef4` |
| `update.ani` | 1,339 | `60497e13f27328a70417528c166710f9bea9055c9e0d14e331ed1e6444ac1686` |
| `bg.ani` | 18,320 | `228b5393b35fc54bb5f98dd8ea7c3d758a956a29c550102d4815aed979e2cc51` |
| `archer.ani` | 4,982 | `77867eee8b0397918dc6db2cd0b90f2726de212b9e6aaa360dea09000b21531a` |
| `brave.ani` | 203,163 | `9f7391beaf2afcdf43c6d0ab4b47e2bcc9b49af2aa377908dd5e714d3c923e61` |
| `canyon.ani` | 60,762 | `0124f3de87a8e13b2f93f4f0da3508ec64b1ce2e2e57ca30b33ce85ce6f40708` |

Important: this is a release-list observation, not a claim that these are all original client files. No APK/AAB appeared among those eight listed assets. Earlier workflow records refer to two larger ZIPs (`ConquerOnline.zip` and `Conquer-Mobile-Assets.-mobile-source-files.zip`); their presence must be re-verified rather than assumed. The dedicated one-cell Colab audit notebook checks the current release API, attempts the exact known archive URLs with size/SHA verification, and scans all retrieved contents for package/version/build metadata.

The loose updater files remain evidence for the resource/update structure, but their names alone do not identify the app version. The later decoded base-APK manifest above supersedes the earlier UNIDENTIFIED status for the Android package version; server-side content revision and regional variant remain unresolved.
