# Canonical mobile source workspace

The source materials are assembled into one folder tree by `.github/workflows/assemble-mobile-source-workspace.yml`.

Output artifact: `Mobile-Source-Workspace`. It contains both original ZIPs, the existing 13,494-row index, prior audit reports, and exploratory quest candidate files side by side.

```text
mobile-source-workspace/
├── 01_ARCHIVES/ (both source ZIPs)
├── 02_INVENTORY/ (resource-source-index.csv)
├── 03_EXISTING_REPORTS/
├── 04_QUEST_CANDIDATES/
├── 05_CURRENT_RUN/
├── workspace-manifest.json
└── README.md
```

The assembly workflow only gathers and verifies existing material. It does not rerun the full inventory or decode pipeline and does not modify game source files.

**Provenance is kept separate:** the historical 13,494-row index was generated from `extracted-assets-001.zip` (842,723,106 bytes; SHA-256 `0d21a110c09b762ed5f1a5f4da022857b0534e489eb85052d15da460cb229d2a`). `ConquerOnline.zip` is a separate 461,117,324-byte upload (SHA-256 `b1c6958109a07c237631943fc0442d3161563d89e1020b143d95437ba9a6fdb0`). Both are preserved and verified separately.

Quest decode candidates are exploratory only; do not use their IDs as confirmed game data until the exact mobile reader/decryption path is established.
