# Mobile APK reader validation — evidence and limits

**Target:** Conquer Online Mobile 1.1.2.3  
**Package reference:** com.Tq.CQ2ClientAndroid  
**Branch:** research/mobile-quest-dat-decoder

## What the current tools establish

1. The archive decoder locates APK members whose archive path contains the pinned version string and records each extracted APK member's byte size and SHA-256.
2. The quest decoder inventories exact-path quest candidates and probes the two currently documented TQ seeds (9527 and 1234). Any decoded Lua-looking output remains a candidate.
3. The APK reader probe enumerates DEX files and native shared libraries inside the exact APK, extracts DEX string tables and printable native strings, and records references that may lead to the quest/resource reader. It also records the extracted APK member's byte size and streaming SHA-256 fingerprint in the reader report.
4. The probe does not disassemble bytecode, resolve obfuscated names, emulate native code, or prove the cipher. A string match is a navigation clue only.

## Why the cipher is not yet accepted

The public Conquer Online Development Wiki describes TQ File Cipher and documents that DAT resources can instead be plain text, binary encoded, RSA encrypted, SWF, or use custom encryption. It also warns that TQ File Cipher only applies to files marked with that format. Its seed examples are from classic desktop client patch documentation, not the target Mobile 1.1.2.3 APK.

References:
- https://conquer-online.github.io/wiki/security/tqfile.html
- https://conquer-online.github.io/wiki/files/formats/dat.html
- https://conquer-online.github.io/wiki/security/rsa.html

Therefore, the 9527/1234 probes are search candidates, not a claim about the Mobile reader. If the APK's DEX/native reader points to RSA, a custom transform, a compressed container, or a different seed/key schedule, the decoder must follow that exact implementation instead.

## Exact APK fingerprint check

The inventory report now records a SHA-256 and size for every extracted APK member. Compare the resulting APK member hash with the external package fingerprint recorded in the quest ecosystem catalogue. A mismatch is not automatically an error: APKPure/XAPK listings may refer to a base APK, split package, or repackaged download. The archive member identity and its own hash remain the primary provenance for this run.

## Acceptance gates

Do not import any extracted quest data into runtime until all of these are satisfied:

- exact APK member and version provenance recorded;
- quest resource path identified in that APK;
- cipher/decompression path independently matched to DEX/native reader behavior;
- decoded bytes pass structural parsing with source offsets and locale preserved;
- field semantics confirmed against the reader/schema, not inferred from field names alone;
- task, NPC, map, monster, item and reward references cross-join to independently extracted records;
- unresolved references and duplicate IDs are reported explicitly;
- integration tests prove quest navigation and objective progression in the Godot runtime.

## Audit environment consistency

The workflow creates a dedicated `.venv`, installs PolyFile there, and now runs compilation, unit tests, and every Python audit script through `.venv/bin/python`. This keeps the `polyfile` Python module import and its command-line executable in the same environment; a successful run must still be confirmed from the workflow's own artifact and logs.

## Known operational limitation

The source-audit workflow is defined on this research branch. The GitHub connector's current workflow-run listing only exposes pull-request-triggered runs, while this workflow uses push/workflow_dispatch triggers. A project build run is not evidence that the source-audit workflow or its unit tests ran. Do not report successful source extraction until the audit artifact itself has been inspected.
