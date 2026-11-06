# Original Conquer C3 skeleton engine findings

## Verified from the original Android ARM64 client binary

The official Android client library `libCQ2ClientEn.so` exports native symbols for the original skeleton system, including:

- `C3DSkeletonX::Load`, `LoadVersion3`, `LoadVersion5`, `LoadVersion7`
- `GetBoneName`, `GetParentBoneID`, `GetBoneCount`, `GetBoneInfo`
- `GetBoneReferencePose`, `GetBonePivot`, `GetPivotPoint`
- `FindBoneByName`, `FindSocketByName`, `GetVirtualPhyBoneId`
- `C3DMotionX::SetSkeleton`, `GetSkeleton`, `CalcuSkeletonOffsetMatrix`
- `C3DMotionX::ApplyDynamicSkeleton`
- `C3DDynamicSkeletonX::TransformBoneDynamically`

This definitively proves that the native client has a real named, parented skeleton hierarchy and socket/pivot system. The old C3-Operator/C3Studio importers did not expose this full hierarchy; their lack of parent assignment was an importer limitation, not evidence that Conquer has no skeleton.

## Version 7 binary layout recovered from ARM64 disassembly

- The loader dispatches skeleton versions 3, 5 and 7.
- Version 7 uses a per-bone source record size of **84 bytes (0x54)**.
- The loader copies each 84-byte record into an internal **88-byte (0x58)** bone record.
- The source record begins with two 16-bit fields. The first is the parent-bone index: `GetParentBoneID` reads a signed 16-bit value from internal record offset 0 and returns -1 for a root. It then checks bit 0 of the flags byte at offset 8 before returning the parent.
- The bone name is stored as a pointer in the internal record at offset 16.
- Four 16-byte blocks are copied from source offsets 20, 36, 52 and 68 into the internal record. These are preserved as opaque matrix/vector data until field semantics are verified.
- The version-7 header contains a signed 16-bit socket count at offset 10. The loader allocates 16-byte socket records and separately copies 12-byte socket payload records.
- The skeleton data structure's bone count is read at offset 0x14; the bone record data begins at offset 0x20.

## Critical correction to the previous research direction

Do not manually construct parent relationships from vertex indices or guess a humanoid rig. The native engine exposes the exact parent index and name lookup. Recover and parse the native skeleton resource/configuration, then match motion data to the corresponding skeleton by exact bone count and skeleton identity.

## Remaining extraction target

The Android package inventory lists `assets/ConquerRes/ini/3dskeleton.ini` and `3dobjprop.ini`, while the WDB contains empty `3DSkeleton.dbc` and `3DObjProp.dbc` records. These INI files must be extracted directly from the APK and inspected alongside `RolePart.dbc`, `3DObj.dbc`, `3DMotion.dbc`, `bodymotiontrans.ini`, and the C3 motion/mesh chunks. Do not mistake the empty DBC files for proof that the native skeleton catalog is absent.

## Validation requirements

- Preserve original bone names, parent indices, pivots, sockets, virtual-physics bone IDs and reference pose.
- Validate all parent indices are -1 or within the skeleton's bone range, and detect cycles.
- Associate each MOTI track with the exact skeleton identity; do not rely on bone count alone.
- Keep body skeleton families separate from monster, NPC, mount and equipment attachment skeletons.
- Export a machine-readable hierarchy and a GLB/Blender rig only after the original hierarchy is recovered.
