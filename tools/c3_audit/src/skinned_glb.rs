use glam::{Mat4, Quat, Vec3};
use sandbox_data::c3::{C3Document, C3Mesh, C3Motion, Matrix4};
use serde_json::{json, Value};
use std::fs;
use std::path::Path;

struct Builder {
    bin: Vec<u8>,
    views: Vec<Value>,
    accessors: Vec<Value>,
}
impl Builder {
    fn new() -> Self { Self { bin: Vec::new(), views: Vec::new(), accessors: Vec::new() } }
    fn align(&mut self) { while self.bin.len() % 4 != 0 { self.bin.push(0); } }
    fn view(&mut self, bytes: &[u8], target: Option<u32>) -> usize {
        self.align();
        let offset = self.bin.len();
        self.bin.extend_from_slice(bytes);
        let mut value = json!({"buffer":0,"byteOffset":offset,"byteLength":bytes.len()});
        if let Some(target) = target { value["target"] = json!(target); }
        self.views.push(value);
        self.views.len() - 1
    }
    fn accessor(&mut self, view: usize, component: u32, count: usize, kind: &str, min: Option<Value>, max: Option<Value>) -> usize {
        let mut value = json!({"bufferView":view,"componentType":component,"count":count,"type":kind});
        if let Some(min) = min { value["min"] = min; }
        if let Some(max) = max { value["max"] = max; }
        self.accessors.push(value);
        self.accessors.len() - 1
    }
}
fn bytes_f32(values: &[f32]) -> Vec<u8> {
    values.iter().flat_map(|v| v.to_le_bytes()).collect()
}
fn bytes_u16(values: &[u16]) -> Vec<u8> {
    values.iter().flat_map(|v| v.to_le_bytes()).collect()
}
fn c3_matrix(matrix: Matrix4) -> Mat4 {
    // C3 stores row-vector matrices; the same 16 floats are column-major
    // when interpreted as the equivalent glTF column-vector transform.
    Mat4::from_cols_array(&matrix.values)
}
fn coordinate_basis() -> Mat4 {
    Mat4::from_rotation_x(std::f32::consts::FRAC_PI_2) * Mat4::from_scale(Vec3::splat(0.01))
}
fn joint_matrix(mesh: &C3Mesh, motion: &C3Motion, bone: u32, frame: f32) -> Mat4 {
    coordinate_basis() * c3_matrix(motion.matrix_at(bone, frame)) * c3_matrix(mesh.initial_matrix)
}
fn static_matrix(mesh: &C3Mesh) -> Mat4 {
    coordinate_basis() * c3_matrix(mesh.initial_matrix)
}
fn decompose(matrix: Mat4) -> Result<(Vec3, Quat, Vec3), String> {
    let (scale, rotation, translation) = matrix.to_scale_rotation_translation();
    if !scale.is_finite() || !rotation.is_finite() || !translation.is_finite() {
        return Err("C3 bone matrix decomposed to non-finite TRS".into());
    }
    let rebuilt = Mat4::from_scale_rotation_translation(scale, rotation, translation);
    let a = matrix.to_cols_array();
    let b = rebuilt.to_cols_array();
    let error = a.iter().zip(b.iter()).map(|(x, y)| (x - y).abs()).fold(0.0_f32, f32::max);
    if error > 0.002 {
        return Err(format!("C3 bone matrix contains non-TRS shear (max reconstruction error {error})"));
    }
    Ok((scale, rotation.normalize(), translation))
}
fn flat3(values: &[[f32; 3]]) -> Vec<f32> { values.iter().flat_map(|v| v.iter().copied()).collect() }
fn normals(positions: &[[f32; 3]], indices: &[u16]) -> Vec<[f32; 3]> {
    let mut result = vec![[0.0_f32; 3]; positions.len()];
    for tri in indices.chunks_exact(3) {
        let (a, b, c) = (tri[0] as usize, tri[1] as usize, tri[2] as usize);
        if a >= positions.len() || b >= positions.len() || c >= positions.len() { continue; }
        let p0 = positions[a]; let p1 = positions[b]; let p2 = positions[c];
        let u = [p1[0]-p0[0], p1[1]-p0[1], p1[2]-p0[2]];
        let v = [p2[0]-p0[0], p2[1]-p0[1], p2[2]-p0[2]];
        let n = [u[1]*v[2]-u[2]*v[1], u[2]*v[0]-u[0]*v[2], u[0]*v[1]-u[1]*v[0]];
        for index in [a,b,c] {
            result[index][0] += n[0]; result[index][1] += n[1]; result[index][2] += n[2];
        }
    }
    result.into_iter().map(|n| {
        let length = (n[0]*n[0] + n[1]*n[1] + n[2]*n[2]).sqrt();
        if length < 1e-8 { [0.0, 1.0, 0.0] } else { [n[0]/length, n[1]/length, n[2]/length] }
    }).collect()
}
fn min_max(values: &[[f32; 3]]) -> (Value, Value) {
    let mut lo = [f32::INFINITY; 3]; let mut hi = [f32::NEG_INFINITY; 3];
    for v in values { for axis in 0..3 { lo[axis] = lo[axis].min(v[axis]); hi[axis] = hi[axis].max(v[axis]); } }
    (json!(lo), json!(hi))
}
fn first_influence(mesh: &C3Mesh, vertex: usize, bone_count: u32) -> Option<u16> {
    let v = &mesh.vertices[vertex];
    for slot in 0..2 {
        if v.bone_weights[slot] > 0.0 {
            let bone = v.bone_indices[slot];
            return (bone < bone_count && bone <= u16::MAX as u32).then_some(bone as u16);
        }
    }
    None
}

pub fn export_document(
    document: &C3Document,
    texture_png: &[u8],
    source: &str,
    output: &Path,
) -> Result<(u64, usize, usize), Box<dyn std::error::Error>> {
    let mut builder = Builder::new();
    let mut meshes = Vec::<Value>::new();
    let mut nodes = vec![json!({"name":"C3_Root","children":[]})];
    let mut root_children = Vec::<usize>::new();
    let mut skins = Vec::<Value>::new();
    let mut samplers = Vec::<Value>::new();
    let mut channels = Vec::<Value>::new();
    let mut mesh_count = 0usize;
    let mut animated_mesh_count = 0usize;
    let mut skin_count = 0usize;

    for (mesh_index, mesh) in document.meshes.iter().enumerate() {
        if mesh.vertices.is_empty() || (mesh.opaque_indices.is_empty() && mesh.alpha_indices.is_empty()) { continue; }
        let motion = document.motions.get(mesh_index);
        let skinned = motion.is_some_and(|m| m.bone_count > 0 && !m.keys.is_empty());
        if let Some(m) = motion {
            if m.bone_count > 65534 { return Err(format!("mesh {} exceeds glTF joint index limit", mesh.name).into()); }
            for (vertex_index, vertex) in mesh.vertices.iter().enumerate() {
                for slot in 0..2 {
                    if vertex.bone_weights[slot] > 0.0 && vertex.bone_indices[slot] >= m.bone_count {
                        return Err(format!("mesh {} vertex {} references bone {} outside motion bone count {}", mesh.name, vertex_index, vertex.bone_indices[slot], m.bone_count).into());
                    }
                }
            }
        }

        let all_indices: Vec<u16> = mesh.opaque_indices.iter().chain(mesh.alpha_indices.iter()).copied().collect();
        let (positions, normal_values, joints_accessor, weights_accessor, skin_index, skeleton_root, mesh_animated) =
            if skinned {
                let motion = motion.expect("skinned mesh has motion");
                let raw_positions: Vec<[f32; 3]> = mesh.vertices.iter().map(|v| [v.position.x, v.position.y, v.position.z]).collect();
                let normal_values = normals(&raw_positions, &all_indices);
                let flat_positions = flat3(&raw_positions);
                let (min, max) = min_max(&raw_positions);
                let pos_view = builder.view(&bytes_f32(&flat_positions), Some(34962));
                let pos_accessor = builder.accessor(pos_view, 5126, raw_positions.len(), "VEC3", Some(min), Some(max));
                let normal_view = builder.view(&bytes_f32(&flat3(&normal_values)), Some(34962));
                let normal_accessor = builder.accessor(normal_view, 5126, normal_values.len(), "VEC3", None, None);
                let flat_uvs: Vec<f32> = mesh.vertices.iter().flat_map(|v| [v.texture_coordinate.x, v.texture_coordinate.y]).collect();
                let uv_view = builder.view(&bytes_f32(&flat_uvs), Some(34962));
                let uv_accessor = builder.accessor(uv_view, 5126, mesh.vertices.len(), "VEC2", None, None);

                let frame_count = motion.frame_count.max(1).min(10000) as usize;
                let bone_count = motion.bone_count as usize;
                let mut root_joint_nodes = Vec::<usize>::new();
                let skeleton_root = nodes.len();
                nodes.push(json!({"name":format!("{}_Skeleton", mesh.name),"children":[]}));

                let mut joint_nodes = Vec::<usize>::new();
                for bone in 0..bone_count {
                    let base = joint_matrix(mesh, motion, bone as u32, 0.0);
                    let (scale, rotation, translation) = decompose(base).map_err(|e| format!("{} bone {}: {}", mesh.name, bone, e))?;
                    let joint_node = nodes.len();
                    nodes.push(json!({
                        "name":format!("{}_c3_bone_{}", mesh.name, bone),
                        "translation":translation.to_array(),
                        "rotation":rotation.to_array(),
                        "scale":scale.to_array()
                    }));
                    joint_nodes.push(joint_node);
                    root_joint_nodes.push(joint_node);

                    if frame_count > 1 {
                        let times: Vec<f32> = (0..frame_count).map(|frame| frame as f32 / 30.0).collect();
                        let time_view = builder.view(&bytes_f32(&times), None);
                        let time_accessor = builder.accessor(time_view, 5126, times.len(), "SCALAR", Some(json!([0.0])), Some(json!([*times.last().unwrap()])));
                        let mut translations = Vec::with_capacity(frame_count * 3);
                        let mut rotations = Vec::with_capacity(frame_count * 4);
                        let mut scales = Vec::with_capacity(frame_count * 3);
                        let mut previous_rotation: Option<Quat> = None;
                        let mut changed = false;
                        for frame in 0..frame_count {
                            let matrix = joint_matrix(mesh, motion, bone as u32, frame as f32);
                            let (s, mut r, t) = decompose(matrix).map_err(|e| format!("{} bone {} frame {}: {}", mesh.name, bone, frame, e))?;
                            if let Some(previous) = previous_rotation {
                                if previous.dot(r) < 0.0 { r = -r; }
                            }
                            if frame > 0 {
                                let offset = frame * 3;
                                changed |= (translations[offset] - t.x).abs() > 1e-6
                                    || (translations[offset+1] - t.y).abs() > 1e-6
                                    || (translations[offset+2] - t.z).abs() > 1e-6;
                            }
                            translations.extend_from_slice(&t.to_array());
                            rotations.extend_from_slice(&r.to_array());
                            scales.extend_from_slice(&s.to_array());
                            previous_rotation = Some(r);
                        }
                        if changed {
                            for (values, kind, path) in [
                                (translations, "VEC3", "translation"),
                                (rotations, "VEC4", "rotation"),
                                (scales, "VEC3", "scale")
                            ] {
                                let view = builder.view(&bytes_f32(&values), None);
                                let accessor = builder.accessor(view, 5126, frame_count, kind, None, None);
                                let sampler = samplers.len();
                                samplers.push(json!({"input":time_accessor,"output":accessor,"interpolation":"LINEAR"}));
                                channels.push(json!({"sampler":sampler,"target":{"node":joint_node,"path":path}}));
                            }
                            animated_mesh_count += 1;
                        }
                    }
                }

                let mut joint_values = Vec::<u16>::with_capacity(mesh.vertices.len() * 4);
                let mut weight_values = Vec::<f32>::with_capacity(mesh.vertices.len() * 4);
                let mut has_unweighted = false;
                for vertex_index in 0..mesh.vertices.len() {
                    if let Some(bone) = first_influence(mesh, vertex_index, motion.bone_count) {
                        joint_values.extend_from_slice(&[bone, 0, 0, 0]);
                        weight_values.extend_from_slice(&[1.0, 0.0, 0.0, 0.0]);
                    } else {
                        has_unweighted = true;
                        joint_values.extend_from_slice(&[motion.bone_count as u16, 0, 0, 0]);
                        weight_values.extend_from_slice(&[1.0, 0.0, 0.0, 0.0]);
                    }
                }
                if has_unweighted {
                    let (scale, rotation, translation) = decompose(static_matrix(mesh))?;
                    let static_node = nodes.len();
                    nodes.push(json!({
                        "name":format!("{}_c3_static", mesh.name),
                        "translation":translation.to_array(),
                        "rotation":rotation.to_array(),
                        "scale":scale.to_array()
                    }));
                    joint_nodes.push(static_node);
                    root_joint_nodes.push(static_node);
                }
                nodes[skeleton_root]["children"] = json!(root_joint_nodes);

                let joints_view = builder.view(&bytes_u16(&joint_values), Some(34962));
                let joints_accessor = builder.accessor(joints_view, 5123, mesh.vertices.len(), "VEC4", None, None);
                let weights_view = builder.view(&bytes_f32(&weight_values), Some(34962));
                let weights_accessor = builder.accessor(weights_view, 5126, mesh.vertices.len(), "VEC4", None, None);

                let identity_values: Vec<f32> = (0..joint_nodes.len()).flat_map(|_| Mat4::IDENTITY.to_cols_array()).collect();
                let ibm_view = builder.view(&bytes_f32(&identity_values), None);
                let ibm_accessor = builder.accessor(ibm_view, 5126, joint_nodes.len(), "MAT4", None, None);
                let skin_index = skins.len();
                skins.push(json!({
                    "name":format!("{}_Skin", mesh.name),
                    "skeleton":skeleton_root,
                    "joints":joint_nodes,
                    "inverseBindMatrices":ibm_accessor
                }));
                skin_count += 1;
                (pos_accessor, normal_accessor, Some(joints_accessor), Some(weights_accessor), Some(skin_index), Some(skeleton_root), frame_count > 1)
            } else {
                let transformed: Vec<[f32; 3]> = mesh.vertices.iter().map(|v| {
                    let p = mesh.initial_matrix.transform_point(v.position);
                    [p.x * 0.01, -p.z * 0.01, p.y * 0.01]
                }).collect();
                let normal_values = normals(&transformed, &all_indices);
                let pos_view = builder.view(&bytes_f32(&flat3(&transformed)), Some(34962));
                let (min, max) = min_max(&transformed);
                let pos_accessor = builder.accessor(pos_view, 5126, transformed.len(), "VEC3", Some(min), Some(max));
                let normal_view = builder.view(&bytes_f32(&flat3(&normal_values)), Some(34962));
                let normal_accessor = builder.accessor(normal_view, 5126, normal_values.len(), "VEC3", None, None);
                let flat_uvs: Vec<f32> = mesh.vertices.iter().flat_map(|v| [v.texture_coordinate.x, v.texture_coordinate.y]).collect();
                let uv_view = builder.view(&bytes_f32(&flat_uvs), Some(34962));
                let uv_accessor = builder.accessor(uv_view, 5126, mesh.vertices.len(), "VEC2", None, None);
                (pos_accessor, normal_accessor, None, None, None, None, false)
            };

        let flat_uvs: Vec<f32> = mesh.vertices.iter().flat_map(|v| [v.texture_coordinate.x, v.texture_coordinate.y]).collect();
        let uv_accessor = if skinned {
            // The skinned branch already created this accessor. Reuse it by locating the last VEC2 accessor.
            builder.accessors.len() - 1
        } else {
            // The static branch also created it immediately after position and normal.
            builder.accessors.len() - 1
        };
        let mut primitives = Vec::<Value>::new();
        for (indices, material) in [(&mesh.opaque_indices, 0_u32), (&mesh.alpha_indices, 1_u32)] {
            if indices.is_empty() { continue; }
            let index_view = builder.view(&bytes_u16(indices), Some(34963));
            let index_accessor = builder.accessor(index_view, 5123, indices.len(), "SCALAR", None, None);
            let mut attributes = json!({"POSITION":positions,"NORMAL":normal_values,"TEXCOORD_0":uv_accessor});
            if let Some(joints) = joints_accessor { attributes["JOINTS_0"] = json!(joints); }
            if let Some(weights) = weights_accessor { attributes["WEIGHTS_0"] = json!(weights); }
            primitives.push(json!({"attributes":attributes,"indices":index_accessor,"material":material,"mode":4}));
        }
        let name = if mesh.name.is_empty() { format!("mesh_{mesh_index}") } else { mesh.name.clone() };
        let gltf_mesh_index = meshes.len();
        meshes.push(json!({"name":name,"primitives":primitives}));
        let node_index = nodes.len();
        let mut node = json!({"name":name,"mesh":gltf_mesh_index});
        if let Some(skin) = skin_index { node["skin"] = json!(skin); }
        nodes.push(node);
        root_children.push(node_index);
        if let Some(skeleton_root) = skeleton_root { root_children.push(skeleton_root); }
        mesh_count += 1;
        let _ = (skin_count, mesh_animated);
    }

    if mesh_count == 0 { return Err("C3 document contains no renderable triangle meshes".into()); }
    nodes[0]["children"] = json!(root_children);
    let image_view = builder.view(texture_png, None);
    let materials = vec![
        json!({"name":"C3 opaque texture","pbrMetallicRoughness":{"baseColorFactor":[1.0,1.0,1.0,1.0],"baseColorTexture":{"index":0},"metallicFactor":0.0,"roughnessFactor":1.0},"doubleSided":true}),
        json!({"name":"C3 alpha texture","pbrMetallicRoughness":{"baseColorFactor":[1.0,1.0,1.0,1.0],"baseColorTexture":{"index":0},"metallicFactor":0.0,"roughnessFactor":1.0},"alphaMode":"BLEND","doubleSided":true})
    ];
    let animations = if channels.is_empty() { Vec::new() } else {
        vec![json!({"name":"C3_Skeletal_Motion","samplers":samplers,"channels":channels})]
    };
    let bin_length = builder.bin.len();
    let mut gltf = json!({
        "asset":{"version":"2.0","generator":"Clash of Legends C3 skeletal GLB exporter"},
        "scene":0,"scenes":[{"nodes":[0]}],"nodes":nodes,"meshes":meshes,
        "materials":materials,
        "samplers":[{"magFilter":9729,"minFilter":9987,"wrapS":10497,"wrapT":10497}],
        "textures":[{"sampler":0,"source":0}],
        "images":[{"bufferView":image_view,"mimeType":"image/png"}],
        "bufferViews":builder.views,"accessors":builder.accessors,
        "buffers":[{"byteLength":bin_length}],
        "animations":animations,
        "extras":{"source_c3":source,"motion_export":"glTF skin with flat C3 joints","skin_count":skin_count,"animated_mesh_count":animated_mesh_count,"bone_influence_rule":"first_positive"}
    });
    if !skins.is_empty() { gltf["skins"] = json!(skins); }
    let mut json_bytes = serde_json::to_vec(&gltf)?;
    while json_bytes.len() % 4 != 0 { json_bytes.push(b' '); }
    builder.align();
    let bin = builder.bin;
    let total = 12 + 8 + json_bytes.len() + 8 + bin.len();
    let mut glb = Vec::with_capacity(total);
    glb.extend_from_slice(&0x46546C67_u32.to_le_bytes());
    glb.extend_from_slice(&2_u32.to_le_bytes());
    glb.extend_from_slice(&(total as u32).to_le_bytes());
    glb.extend_from_slice(&(json_bytes.len() as u32).to_le_bytes());
    glb.extend_from_slice(&0x4E4F534A_u32.to_le_bytes());
    glb.extend_from_slice(&json_bytes);
    glb.extend_from_slice(&(bin.len() as u32).to_le_bytes());
    glb.extend_from_slice(&0x004E4942_u32.to_le_bytes());
    glb.extend_from_slice(&bin);
    if let Some(parent) = output.parent() { fs::create_dir_all(parent)?; }
    fs::write(output, &glb)?;
    Ok((glb.len() as u64, mesh_count, animated_mesh_count))
}
