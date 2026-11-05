use sandbox_data::c3::{C3Document, Matrix4};
use serde_json::{json, Value};
use std::fs;
use std::path::Path;

struct GlbBuilder {
    bin: Vec<u8>,
    views: Vec<Value>,
    accessors: Vec<Value>,
}

impl GlbBuilder {
    fn new() -> Self { Self { bin: Vec::new(), views: Vec::new(), accessors: Vec::new() } }

    fn align(&mut self) {
        while self.bin.len() % 4 != 0 { self.bin.push(0); }
    }

    fn add_view(&mut self, bytes: &[u8], target: Option<u32>) -> usize {
        self.align();
        let offset = self.bin.len();
        self.bin.extend_from_slice(bytes);
        let mut view = json!({"buffer":0,"byteOffset":offset,"byteLength":bytes.len()});
        if let Some(value) = target { view["target"] = json!(value); }
        self.views.push(view);
        self.views.len() - 1
    }

    fn add_accessor(&mut self, view: usize, component_type: u32, count: usize, kind: &str, min: Option<Value>, max: Option<Value>) -> usize {
        let mut accessor = json!({"bufferView":view,"componentType":component_type,"count":count,"type":kind});
        if let Some(value) = min { accessor["min"] = value; }
        if let Some(value) = max { accessor["max"] = value; }
        self.accessors.push(accessor);
        self.accessors.len() - 1
    }
}

fn f32_bytes(values: &[f32]) -> Vec<u8> {
    let mut out = Vec::with_capacity(values.len() * 4);
    for value in values { out.extend_from_slice(&value.to_le_bytes()); }
    out
}

fn u16_bytes(values: &[u16]) -> Vec<u8> {
    let mut out = Vec::with_capacity(values.len() * 2);
    for value in values { out.extend_from_slice(&value.to_le_bytes()); }
    out
}

fn transformed_positions(mesh: &sandbox_data::c3::C3Mesh, motion: Option<&sandbox_data::c3::C3Motion>, frame: f32) -> Result<Vec<[f32; 3]>, String> {
    mesh.vertices.iter().enumerate().map(|(vertex_index, vertex)| {
        let point = if let Some(motion) = motion {
            crate::skinned_glb::weighted_c3_position(mesh, motion, vertex_index, frame)?
        } else {
            mesh.initial_matrix.transform_point(vertex.position)
        };
        Ok([point.x * 0.01, -point.z * 0.01, point.y * 0.01])
    }).collect()
}

fn morph_deltas(base: &[[f32; 3]], frame: &[[f32; 3]]) -> Vec<f32> {
    base.iter().zip(frame.iter()).flat_map(|(a, b)| [
        b[0] - a[0], b[1] - a[1], b[2] - a[2]
    ]).collect()
}

fn normal_deltas(base: &[[f32; 3]], frame: &[[f32; 3]]) -> Vec<f32> {
    base.iter().zip(frame.iter()).flat_map(|(a, b)| [
        b[0] - a[0], b[1] - a[1], b[2] - a[2]
    ]).collect()
}

fn normalize(v: [f32; 3]) -> [f32; 3] {
    let length = (v[0]*v[0] + v[1]*v[1] + v[2]*v[2]).sqrt();
    if length < 0.000001 { [0.0, 1.0, 0.0] } else { [v[0]/length, v[1]/length, v[2]/length] }
}

fn compute_normals(positions: &[[f32; 3]], indices: &[u16]) -> Vec<[f32; 3]> {
    let mut normals = vec![[0.0_f32; 3]; positions.len()];
    for tri in indices.chunks_exact(3) {
        let a = tri[0] as usize;
        let b = tri[1] as usize;
        let c = tri[2] as usize;
        if a >= positions.len() || b >= positions.len() || c >= positions.len() { continue; }
        let p0 = positions[a]; let p1 = positions[b]; let p2 = positions[c];
        let u = [p1[0]-p0[0], p1[1]-p0[1], p1[2]-p0[2]];
        let v = [p2[0]-p0[0], p2[1]-p0[1], p2[2]-p0[2]];
        let n = [u[1]*v[2]-u[2]*v[1], u[2]*v[0]-u[0]*v[2], u[0]*v[1]-u[1]*v[0]];
        for index in [a,b,c] {
            normals[index][0] += n[0];
            normals[index][1] += n[1];
            normals[index][2] += n[2];
        }
    }
    normals.into_iter().map(normalize).collect()
}

fn accessor_min_max(values: &[[f32; 3]]) -> (Value, Value) {
    let mut min = [f32::INFINITY; 3];
    let mut max = [f32::NEG_INFINITY; 3];
    for p in values {
        for axis in 0..3 {
            min[axis] = min[axis].min(p[axis]);
            max[axis] = max[axis].max(p[axis]);
        }
    }
    (json!([min[0],min[1],min[2]]), json!([max[0],max[1],max[2]]))
}

pub fn export_document_with_external_motion(
    base_document: &C3Document,
    motion_document: &C3Document,
    texture_png: &[u8],
    source: &str,
    output: &Path,
) -> Result<(u64, usize, usize), Box<dyn std::error::Error>> {
    if base_document.meshes.len() != motion_document.motions.len() {
        return Err(format!(
            "external motion has {} MOTI chunks for {} base PHY meshes",
            motion_document.motions.len(),
            base_document.meshes.len()
        ).into());
    }
    for (mesh_index, (mesh, motion)) in base_document.meshes.iter().zip(motion_document.motions.iter()).enumerate() {
        for vertex in &mesh.vertices {
            for influence in 0..2 {
                if vertex.bone_weights[influence] > 0.0
                    && u32::from(vertex.bone_indices[influence]) >= motion.bone_count
                {
                    return Err(format!(
                        "external motion mesh slot {mesh_index} has {} bones but a vertex references bone {}",
                        motion.bone_count,
                        vertex.bone_indices[influence]
                    ).into());
                }
            }
        }
    }
    let mut merged_document = base_document.clone();
    merged_document.motions = motion_document.motions.clone();
    export_document(&merged_document, texture_png, source, output)
}

pub fn export_document(document: &C3Document, texture_png: &[u8], source: &str, output: &Path) -> Result<(u64, usize, usize), Box<dyn std::error::Error>> {
    let mut builder = GlbBuilder::new();
    let mut gltf_meshes: Vec<Value> = Vec::new();
    let mut nodes: Vec<Value> = vec![json!({"name":"C3_Root","children":[]})];
    let mut children: Vec<usize> = Vec::new();
    let mut animation_samplers: Vec<Value> = Vec::new();
    let mut animation_channels: Vec<Value> = Vec::new();
    let mut animation_frame_report: Vec<Value> = Vec::new();
    let mut mesh_count = 0usize;
    let mut animated_mesh_count = 0usize;

    // C3 documents commonly store one MOTI chunk per PHY mesh. Do not reuse
    // document.motions.first() for every mesh: that freezes most body parts.
    for (mesh_index, mesh) in document.meshes.iter().enumerate() {
        if mesh.vertices.is_empty() || (mesh.opaque_indices.is_empty() && mesh.alpha_indices.is_empty()) {
            continue;
        }
        let motion = document.motions.get(mesh_index);
        // VAT stores frame zero as its base row. The GLB morph base must use
        // that exact same C3 sample even when a mesh's first MOTI key starts
        // later than frame zero; otherwise source vertex-order validation
        // correctly detects different base positions for large body meshes.
        let mut sample_frames: Vec<f32> = vec![0.0];
        if let Some(motion) = motion {
            if motion.keys.len() > 1 {
                let sample_count = motion.keys.len().min(11);
                for sample_index in 0..sample_count {
                    let key_index = sample_index * (motion.keys.len() - 1) / (sample_count - 1);
                    let frame = motion.keys[key_index].frame as f32;
                    if !sample_frames.iter().any(|existing| (*existing - frame).abs() < 0.0001) {
                        sample_frames.push(frame);
                    }
                }
            } else if let Some(key) = motion.keys.first() {
                let frame = key.frame as f32;
                if !sample_frames.iter().any(|existing| (*existing - frame).abs() < 0.0001) {
                    sample_frames.push(frame);
                }
            }
        }
        let animated = sample_frames.len() > 1;
        let target_count = if animated { sample_frames.len() - 1 } else { 0 };

        let positions_by_frame: Vec<Vec<[f32; 3]>> = sample_frames.iter()
            .map(|frame| transformed_positions(mesh, motion, *frame))
            .collect::<Result<_, _>>()?;
        let positions = &positions_by_frame[0];
        let all_indices: Vec<u16> = mesh.opaque_indices.iter()
            .chain(mesh.alpha_indices.iter()).copied().collect();
        let normals = compute_normals(positions, &all_indices);
        let flat_positions: Vec<f32> = positions.iter().flat_map(|p| p.iter().copied()).collect();
        let flat_normals: Vec<f32> = normals.iter().flat_map(|p| p.iter().copied()).collect();
        let flat_uvs: Vec<f32> = mesh.vertices.iter()
            .flat_map(|v| [v.texture_coordinate.x, v.texture_coordinate.y]).collect();
        // TEXCOORD_1 preserves the original C3 vertex ID. Godot may split
        // imported vertices along normal/material boundaries; duplicates keep
        // this source index so VAT lookup remains stable after import.
        let source_width = mesh.vertices.len() as f32;
        let flat_source_indices: Vec<f32> = (0..mesh.vertices.len())
            .flat_map(|index| [(index as f32 + 0.5) / source_width, 0.5]).collect();
        let (min, max) = accessor_min_max(positions);

        let pos_view = builder.add_view(&f32_bytes(&flat_positions), Some(34962));
        let pos_accessor = builder.add_accessor(pos_view, 5126, positions.len(), "VEC3", Some(min), Some(max));
        let normal_view = builder.add_view(&f32_bytes(&flat_normals), Some(34962));
        let normal_accessor = builder.add_accessor(normal_view, 5126, normals.len(), "VEC3", None, None);
        let uv_view = builder.add_view(&f32_bytes(&flat_uvs), Some(34962));
        let uv_accessor = builder.add_accessor(uv_view, 5126, mesh.vertices.len(), "VEC2", None, None);
        let source_index_view = builder.add_view(&f32_bytes(&flat_source_indices), Some(34962));
        let source_index_accessor = builder.add_accessor(source_index_view, 5126, mesh.vertices.len(), "VEC2", None, None);

        let mut targets: Vec<Value> = Vec::new();
        if animated {
            for frame_index in 1..sample_frames.len() {
                let frame_positions = &positions_by_frame[frame_index];
                let position_delta = morph_deltas(positions, frame_positions);
                let pos_delta_view = builder.add_view(&f32_bytes(&position_delta), Some(34962));
                let pos_delta_accessor = builder.add_accessor(pos_delta_view, 5126, positions.len(), "VEC3", None, None);
                let frame_normals = compute_normals(frame_positions, &all_indices);
                let normal_delta = normal_deltas(&normals, &frame_normals);
                let normal_delta_view = builder.add_view(&f32_bytes(&normal_delta), Some(34962));
                let normal_delta_accessor = builder.add_accessor(normal_delta_view, 5126, normals.len(), "VEC3", None, None);
                targets.push(json!({"POSITION":pos_delta_accessor,"NORMAL":normal_delta_accessor}));
            }
        }

        let mut primitives: Vec<Value> = Vec::new();
        if !mesh.opaque_indices.is_empty() {
            let view = builder.add_view(&u16_bytes(&mesh.opaque_indices), Some(34963));
            let accessor = builder.add_accessor(view, 5123, mesh.opaque_indices.len(), "SCALAR", None, None);
            let mut primitive = json!({"attributes":{"POSITION":pos_accessor,"NORMAL":normal_accessor,"TEXCOORD_0":uv_accessor,"TEXCOORD_1":source_index_accessor},"indices":accessor,"material":0,"mode":4});
            if animated { primitive["targets"] = json!(targets); }
            primitives.push(primitive);
        }
        if !mesh.alpha_indices.is_empty() {
            let view = builder.add_view(&u16_bytes(&mesh.alpha_indices), Some(34963));
            let accessor = builder.add_accessor(view, 5123, mesh.alpha_indices.len(), "SCALAR", None, None);
            let mut primitive = json!({"attributes":{"POSITION":pos_accessor,"NORMAL":normal_accessor,"TEXCOORD_0":uv_accessor,"TEXCOORD_1":source_index_accessor},"indices":accessor,"material":1,"mode":4});
            if animated { primitive["targets"] = json!(targets); }
            primitives.push(primitive);
        }
        if primitives.is_empty() {
            continue;
        }
        let name = if mesh.name.is_empty() { format!("mesh_{mesh_index}") } else { mesh.name.clone() };
        let gltf_index = gltf_meshes.len();
        let weights = vec![0.0_f32; target_count];
        let mut gltf_mesh = json!({"name":name.clone(),"primitives":primitives});
        if animated { gltf_mesh["weights"] = json!(weights); }
        gltf_meshes.push(gltf_mesh);
        let node_index = nodes.len();
        let mut node = json!({"name":name.clone(),"mesh":gltf_index});
        if animated { node["weights"] = json!(weights); }
        nodes.push(node);
        children.push(node_index);
        mesh_count += 1;

        if animated {
            let first_frame = sample_frames[0];
            let times: Vec<f32> = sample_frames.iter()
                .map(|frame| (*frame - first_frame).max(0.0) / 30.0).collect();
            let time_view = builder.add_view(&f32_bytes(&times), None);
            let time_accessor = builder.add_accessor(
                time_view, 5126, times.len(), "SCALAR",
                Some(json!([times[0]])),
                Some(json!([*times.last().unwrap()])),
            );
            let mut weight_values: Vec<f32> = Vec::with_capacity(sample_frames.len() * target_count);
            for key_index in 0..sample_frames.len() {
                for target_index in 0..target_count {
                    weight_values.push(if key_index == 0 { 0.0 } else if target_index == key_index - 1 { 1.0 } else { 0.0 });
                }
            }
            let weight_view = builder.add_view(&f32_bytes(&weight_values), None);
            let weight_accessor = builder.add_accessor(weight_view, 5126, weight_values.len(), "SCALAR", None, None);
            let sampler_index = animation_samplers.len();
            animation_samplers.push(json!({"input":time_accessor,"output":weight_accessor,"interpolation":"LINEAR"}));
            animation_channels.push(json!({"sampler":sampler_index,"target":{"node":node_index,"path":"weights"}}));
            animation_frame_report.push(json!({"mesh":name,"motion_index":mesh_index,"sample_frames":sample_frames}));
            animated_mesh_count += 1;
        }
    }

    if mesh_count == 0 {
        return Err("C3 document contains no renderable triangle meshes".into());
    }
    nodes[0]["children"] = json!(children);

    let image_view = builder.add_view(texture_png, None);
    let materials = vec![
        json!({"name":"C3 opaque texture","pbrMetallicRoughness":{"baseColorFactor":[1.0,1.0,1.0,1.0],"baseColorTexture":{"index":0},"metallicFactor":0.0,"roughnessFactor":1.0},"doubleSided":true}),
        json!({"name":"C3 alpha texture","pbrMetallicRoughness":{"baseColorFactor":[1.0,1.0,1.0,1.0],"baseColorTexture":{"index":0},"metallicFactor":0.0,"roughnessFactor":1.0},"alphaMode":"BLEND","doubleSided":true})
    ];
    let animations = if animation_channels.is_empty() {
        Vec::new()
    } else {
        vec![json!({"name":"C3_Motion_0","samplers":animation_samplers,"channels":animation_channels})]
    };
    let motion_info: Vec<Value> = document.motions.iter()
        .map(|m| json!({"bone_count":m.bone_count,"frame_count":m.frame_count,"key_count":m.keys.len(),"morph_count":m.morph_count}))
        .collect();
    let bin_length = builder.bin.len();
    let gltf = json!({
        "asset":{"version":"2.0","generator":"Clash of Legends C3/PVR converter with per-mesh sampled motion morphs"},
        "scene":0,
        "scenes":[{"nodes":[0]}],
        "nodes":nodes,
        "meshes":gltf_meshes,
        "materials":materials,
        "samplers":[{"magFilter":9729,"minFilter":9987,"wrapS":10497,"wrapT":10497}],
        "textures":[{"sampler":0,"source":0}],
        "images":[{"bufferView":image_view,"mimeType":"image/png"}],
        "bufferViews":builder.views,
        "accessors":builder.accessors,
        "buffers":[{"byteLength":bin_length}],
        "animations":animations,
        "extras":{
            "source_c3":source,
            "coordinate_conversion":"C3 Z-down to glTF Y-up",
            "unit_scale":0.01,
            "motion_chunks":motion_info,
            "motion_export":"per-mesh sampled morph animation",
            "animation_fps":30,
            "animated_mesh_count":animated_mesh_count,
            "motion_sample_frames":animation_frame_report
        }
    });
    let mut json_bytes = serde_json::to_vec(&gltf)?;
    while json_bytes.len() % 4 != 0 { json_bytes.push(b' '); }
    builder.align();
    let bin_bytes = builder.bin;
    let total_length = 12 + 8 + json_bytes.len() + 8 + bin_bytes.len();
    let mut glb = Vec::with_capacity(total_length);
    glb.extend_from_slice(&0x46546C67_u32.to_le_bytes());
    glb.extend_from_slice(&2_u32.to_le_bytes());
    glb.extend_from_slice(&(total_length as u32).to_le_bytes());
    glb.extend_from_slice(&(json_bytes.len() as u32).to_le_bytes());
    glb.extend_from_slice(&0x4E4F534A_u32.to_le_bytes());
    glb.extend_from_slice(&json_bytes);
    glb.extend_from_slice(&(bin_bytes.len() as u32).to_le_bytes());
    glb.extend_from_slice(&0x004E4942_u32.to_le_bytes());
    glb.extend_from_slice(&bin_bytes);
    if let Some(parent) = output.parent() { fs::create_dir_all(parent)?; }
    fs::write(output, &glb)?;
    Ok((glb.len() as u64, mesh_count, animated_mesh_count))
}

#[cfg(test)]
mod tests {
    use super::*;
    use sandbox_data::c3::{C3Document, C3Mesh, C3Motion, C3Vertex, Matrix4, MotionKey, Vector2, Vector3};

    fn mesh(name: &str) -> C3Mesh {
        C3Mesh {
            name: name.to_owned(),
            blend_count: 0,
            opaque_vertex_count: 3,
            alpha_vertex_count: 0,
            vertices: vec![
                C3Vertex { position: Vector3 { x: 0.0, y: 0.0, z: 0.0 }, texture_coordinate: Vector2 { x: 0.0, y: 0.0 }, colour: 0, bone_indices: [0, 0], bone_weights: [1.0, 0.0] },
                C3Vertex { position: Vector3 { x: 1.0, y: 0.0, z: 0.0 }, texture_coordinate: Vector2 { x: 1.0, y: 0.0 }, colour: 0, bone_indices: [0, 0], bone_weights: [1.0, 0.0] },
                C3Vertex { position: Vector3 { x: 0.0, y: 1.0, z: 0.0 }, texture_coordinate: Vector2 { x: 0.0, y: 1.0 }, colour: 0, bone_indices: [0, 0], bone_weights: [1.0, 0.0] }
            ],
            opaque_indices: vec![0, 1, 2],
            alpha_indices: Vec::new(),
            texture_name: String::new(),
            bounds_minimum: Vector3 { x: 0.0, y: 0.0, z: 0.0 },
            bounds_maximum: Vector3 { x: 1.0, y: 1.0, z: 0.0 },
            initial_matrix: Matrix4::IDENTITY,
            texture_rows: 1,
            transparency_keys: Vec::new(),
            draw_keys: Vec::new(),
            texture_keys: Vec::new(),
            extension_tag: None,
        }
    }

    fn motion(frame_count: u32, frames: &[u32]) -> C3Motion {
        let keys = frames.iter().map(|frame| {
            let mut matrix = Matrix4::IDENTITY;
            matrix.values[12] = *frame as f32;
            MotionKey { frame: *frame, bone_matrices: vec![matrix] }
        }).collect();
        C3Motion { bone_count: 1, frame_count, keys, morph_count: 0, morph_values: Vec::new() }
    }

    #[test]
    fn sampled_deformation_matches_normalized_weighted_c3_influences() {
        let mut source = mesh("two_slot_vertex");
        source.vertices[0].bone_indices = [0, 1];
        source.vertices[0].bone_weights = [0.25, 0.75];
        let mut first = Matrix4::IDENTITY;
        first.values[12] = 4.0;
        let mut second = Matrix4::IDENTITY;
        second.values[12] = 40.0;
        let motion = C3Motion {
            bone_count: 2,
            frame_count: 1,
            keys: vec![MotionKey { frame: 0, bone_matrices: vec![first, second] }],
            morph_count: 0,
            morph_values: Vec::new(),
        };
        let result = transformed_positions(&source, Some(&motion), 0.0).unwrap();
        // 25% of the first transform (4) plus 75% of the second (40) = 31 cm.
        assert!((result[0][0] - 0.31).abs() < 0.00001);
    }

    #[test]
    fn external_motion_replaces_static_embedded_motion_for_each_phy_slot() {
        let base_document = C3Document {
            version: "base".to_owned(),
            meshes: vec![mesh("body"), mesh("arm")],
            motions: vec![motion(21, &[0]), motion(21, &[0])],
            unknown_chunks: Vec::new(),
        };
        let motion_document = C3Document {
            version: "motion-only".to_owned(),
            meshes: Vec::new(),
            motions: vec![motion(21, &[0, 10, 20]), motion(21, &[0, 10, 20])],
            unknown_chunks: Vec::new(),
        };
        let png = [
            137,80,78,71,13,10,26,10,0,0,0,13,73,72,68,82,0,0,0,1,0,0,0,1,
            8,6,0,0,0,31,21,196,137,0,0,0,13,73,68,65,84,120,156,99,248,207,192,
            240,31,0,5,0,1,255,137,153,61,29,0,0,0,0,73,69,78,68,174,66,96,130
        ];
        let output = std::env::temp_dir().join(format!("c3-external-motion-{}.glb", std::process::id()));
        let (_, meshes_written, animated_meshes) = export_document_with_external_motion(
            &base_document, &motion_document, &png, "base+motion.c3", &output
        ).unwrap();
        assert_eq!(meshes_written, 2);
        assert_eq!(animated_meshes, 2);
        let glb = fs::read(&output).unwrap();
        let json_length = u32::from_le_bytes(glb[12..16].try_into().unwrap()) as usize;
        let json: Value = serde_json::from_slice(&glb[20..20 + json_length]).unwrap();
        assert_eq!(json["animations"][0]["channels"].as_array().unwrap().len(), 2);
        fs::remove_file(output).unwrap();
    }

    #[test]
    fn rejects_external_motion_with_wrong_mesh_count() {
        let base_document = C3Document {
            version: "base".to_owned(),
            meshes: vec![mesh("body"), mesh("arm")],
            motions: vec![motion(1, &[0]), motion(1, &[0])],
            unknown_chunks: Vec::new(),
        };
        let motion_document = C3Document {
            version: "motion-only".to_owned(),
            meshes: Vec::new(),
            motions: vec![motion(21, &[0, 10, 20])],
            unknown_chunks: Vec::new(),
        };
        let png = [0_u8; 0];
        let output = std::env::temp_dir().join(format!("c3-invalid-external-motion-{}.glb", std::process::id()));
        assert!(export_document_with_external_motion(
            &base_document, &motion_document, &png, "bad.c3", &output
        ).is_err());
        assert!(!output.exists());
    }

    #[test]
    fn exports_animation_from_the_motion_matching_each_mesh() {
        let document = C3Document {
            version: "test".to_owned(),
            meshes: vec![mesh("static_mesh"), mesh("animated_mesh")],
            motions: vec![motion(1, &[0]), motion(21, &[0, 10, 20])],
            unknown_chunks: Vec::new(),
        };
        let png = [
            137,80,78,71,13,10,26,10,0,0,0,13,73,72,68,82,0,0,0,1,0,0,0,1,
            8,6,0,0,0,31,21,196,137,0,0,0,13,73,68,65,84,120,156,99,248,207,192,
            240,31,0,5,0,1,255,137,153,61,29,0,0,0,0,73,69,78,68,174,66,96,130
        ];
        let output = std::env::temp_dir().join(format!("c3-per-mesh-motion-{}.glb", std::process::id()));
        let (bytes_written, meshes_written, animated_meshes) =
            export_document(&document, &png, "test.c3", &output).unwrap();
        assert!(bytes_written > 0);
        assert_eq!(meshes_written, 2);
        assert_eq!(animated_meshes, 1);
        let glb = fs::read(&output).unwrap();
        let json_length = u32::from_le_bytes(glb[12..16].try_into().unwrap()) as usize;
        let json: Value = serde_json::from_slice(&glb[20..20 + json_length]).unwrap();
        assert_eq!(json["animations"].as_array().unwrap().len(), 1);
        assert_eq!(json["animations"][0]["channels"].as_array().unwrap().len(), 1);
        assert_eq!(json["animations"][0]["samplers"].as_array().unwrap().len(), 1);
        assert_eq!(json["meshes"][1]["primitives"][0]["targets"].as_array().unwrap().len(), 2);
        let source_index_accessor = json["meshes"][1]["primitives"][0]["attributes"]["TEXCOORD_1"].as_u64().unwrap() as usize;
        assert_eq!(json["accessors"][source_index_accessor]["count"], 3);
        fs::remove_file(output).unwrap();
    }
}
