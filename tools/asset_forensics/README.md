# External asset-forensics toolchain

This is the project-integrated intake path for source archives. It is independent of the failed GitHub Draft-release download route.

## Free / open tools
- 7-Zip / p7zip and libarchive/bsdtar: independent archive listing and extraction for common containers.
- QuickBMS: optional specialist extractor when a proprietary container has a matching, reviewed BMS script. Never execute an unknown script in a trusted workspace.
- Kaitai Struct + kaitaistruct: formal binary-format descriptions and generated parsers for validated C3 / skeleton / motion records.
- Blender: batch inspection/conversion of validated geometry and animation to glTF 2.0 / GLB.
- ffmpeg / ffprobe: audio/video codec, duration, stream and channel inspection.
- binwalk: signature-based discovery of embedded payloads; a hit is a lead, not proof of a valid asset.

## Run
Open notebooks/Run_External_Asset_Forensics.ipynb in Colab and run its single cell. It mounts Drive, lets you choose the original archive manually, installs the tools, runs this scanner, and stores the report plus extracted source tree under MyDrive/ClashOfLegends_Forensics/.

Local Linux:
    sudo apt-get install p7zip-full libarchive-tools binwalk ffmpeg
    python3 tools/asset_forensics/run_forensics.py /path/to/source.zip --out /path/to/private-output

## Integration contract
1. Raw source files and derivatives stay in private staging until provenance and rights are reviewed.
2. Each candidate gets SHA-256, source path, size, signature and category tags.
3. Skeleton, bone, socket and motion data are never fabricated. Promote a parser only after record boundaries, parent links, pivots and animation tracks pass fixtures.
4. Convert validated models to GLB while preserving armatures and clips; Godot imports glTF/GLB.
5. Link textures, UI, audio and gameplay data through manifests before switching scenes or systems.
6. Approved outputs are integrated into the existing Godot project and tested in a real scene.

## Distribution boundary
PUBLIC_RESOURCE_DISTRIBUTION_POLICY.md excludes source-derived Conquer assets and converted derivatives from public releases until redistribution rights are established. This tool writes to private Google Drive staging, not tracked assets/.
