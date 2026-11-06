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


## Additional verified accessors recovered from native disassembly

The following accessor behavior is now confirmed at instruction level:

- `GetBoneName(i)` validates the signed index against the bone vector and returns the 64-bit name pointer stored at internal bone-record offset `0x10`. This confirms that the field is a pointer, not an inline fixed-length name.
- `GetBoneReferencePose(i, matrix)` copies exactly 64 bytes from internal offsets `0x18..0x57` into the output matrix. These four 16-byte blocks are the full reference-pose matrix payload.
- `GetPivotPoint(i)` reads three 32-bit floats at internal offsets `0x48`, `0x4C`, and `0x50`. These values overlap the final 16-byte block of the reference-pose payload; preserve the complete 64-byte matrix and expose this 3-float accessor separately rather than discarding either representation.
- `GetParentBoneID(i)` reads a signed 16-bit parent at offset `0x00`. A value of -1 is the root sentinel. For non-root entries, it checks bit 0 of the candidate parent's flags byte at offset `0x08`; if the bit is not set, it returns -1. A parser must reproduce this validation rather than trusting every raw parent index.
- `IsBoneInheritFromBone(child, ancestor)` follows the parent chain by repeatedly reading each record's signed parent index, with -1 terminating the walk. This confirms that the parent field is used as a true ancestry chain, not merely a display grouping.
- The socket array is stored separately from the bone vector. `FindSocketByName` iterates 16-byte internal socket records and compares the name pointer at record offset `0x08`; `IsSocketInheritFromBone` checks the socket's attached bone and then follows the same parent chain.
- The separate-root-bone accessor returns a stored integer at skeleton-object offset `0x10`. Preserve it as skeleton metadata; do not assume the only root is the bone whose parent is -1.

## Safe parsing implications

1. Keep the raw 84-byte V7 record and the normalized 88-byte internal-layout interpretation side by side during reverse engineering.
2. Resolve name pointers only after the loader's relocation/string-table stage is understood. Never treat the 64-bit pointer bytes as a string offset without proof.
3. Preserve all 64 reference-pose bytes, the three pivot floats, flags, parent sentinel, socket records and separate-root-bone ID.
4. Validate parent references and ancestry chains before exporting a Godot `Skeleton3D`; reject cycles and out-of-range links.
5. Do not build or retarget animation tracks until the source skeleton resource and its name-pointer resolution have been recovered.
