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

pub fn export_document(document: &C3Document, texture_png: &[u8], source: &str, output: &Path) -> Result<(u64, usize), Box<dyn std::error::Error>> {
    let mut builder = GlbBuilder::new();
    let mut gltf_meshes: Vec<Value> = Vec::new();
    let mut nodes: Vec<Value> = vec![json!({"name":"C3_Root","children":[]})];
    let mut children: Vec<usize> = Vec::new();
    let motion = document.motions.first();
    let mut mesh_count = 0usize;

    for (mesh_index, mesh) in document.meshes.iter().enumerate() {
        if mesh.vertices.is_empty() || (mesh.opaque_indices.is_empty() && mesh.alpha_indices.is_empty()) { continue; }
        let mut positions: Vec<[f32; 3]> = Vec::with_capacity(mesh.vertices.len());
        let mut uvs: Vec<[f32; 2]> = Vec::with_capacity(mesh.vertices.len());
        for vertex in &mesh.vertices {
            let point = if let Some(motion) = motion {
                mesh.transformed_vertex_position(vertex, motion, Matrix4::IDENTITY, 0.0)
            } else {
                mesh.initial_matrix.transform_point(vertex.position)
            };
            // NetDragon C3 uses Z-down; convert to Y-up and centimeters to meters.
            positions.push([point.x * 0.01, -point.z * 0.01, point.y * 0.01]);
            uvs.push([vertex.texture_coordinate.x, vertex.texture_coordinate.y]);
        }
        let mut all_indices = mesh.opaque_indices.clone();
        all_indices.extend_from_slice(&mesh.alpha_indices);
        let normals = compute_normals(&positions, &all_indices);
        let flat_positions: Vec<f32> = positions.iter().flat_map(|p| p.iter().copied()).collect();
        let flat_normals: Vec<f32> = normals.iter().flat_map(|p| p.iter().copied()).collect();
        let flat_uvs: Vec<f32> = uvs.iter().flat_map(|p| p.iter().copied()).collect();
        let (min, max) = accessor_min_max(&positions);

        let pos_view = builder.add_view(&f32_bytes(&flat_positions), Some(34962));
        let pos_accessor = builder.add_accessor(pos_view, 5126, positions.len(), "VEC3", Some(min), Some(max));
        let normal_view = builder.add_view(&f32_bytes(&flat_normals), Some(34962));
        let normal_accessor = builder.add_accessor(normal_view, 5126, normals.len(), "VEC3", None, None);
        let uv_view = builder.add_view(&f32_bytes(&flat_uvs), Some(34962));
        let uv_accessor = builder.add_accessor(uv_view, 5126, uvs.len(), "VEC2", None, None);

        let mut primitives: Vec<Value> = Vec::new();
        if !mesh.opaque_indices.is_empty() {
            let view = builder.add_view(&u16_bytes(&mesh.opaque_indices), Some(34963));
            let accessor = builder.add_accessor(view, 5123, mesh.opaque_indices.len(), "SCALAR", None, None);
            primitives.push(json!({"attributes":{"POSITION":pos_accessor,"NORMAL":normal_accessor,"TEXCOORD_0":uv_accessor},"indices":accessor,"material":0,"mode":4}));
        }
        if !mesh.alpha_indices.is_empty() {
            let view = builder.add_view(&u16_bytes(&mesh.alpha_indices), Some(34963));
            let accessor = builder.add_accessor(view, 5123, mesh.alpha_indices.len(), "SCALAR", None, None);
            primitives.push(json!({"attributes":{"POSITION":pos_accessor,"NORMAL":normal_accessor,"TEXCOORD_0":uv_accessor},"indices":accessor,"material":1,"mode":4}));
        }
        if primitives.is_empty() { continue; }
        let name = if mesh.name.is_empty() { format!("mesh_{mesh_index}") } else { mesh.name.clone() };
        let gltf_index = gltf_meshes.len();
        gltf_meshes.push(json!({"name":name,"primitives":primitives}));
        let node_index = nodes.len();
        nodes.push(json!({"name":name,"mesh":gltf_index}));
        children.push(node_index);
        mesh_count += 1;
    }
    if mesh_count == 0 { return Err("C3 document contains no renderable triangle meshes".into()); }
    nodes[0]["children"] = json!(children);

    let image_view = builder.add_view(texture_png, None);
    let materials = vec![
        json!({"name":"C3 opaque texture","pbrMetallicRoughness":{"baseColorFactor":[1.0,1.0,1.0,1.0],"baseColorTexture":{"index":0},"metallicFactor":0.0,"roughnessFactor":1.0},"doubleSided":true}),
        json!({"name":"C3 alpha texture","pbrMetallicRoughness":{"baseColorFactor":[1.0,1.0,1.0,1.0],"baseColorTexture":{"index":0},"metallicFactor":0.0,"roughnessFactor":1.0},"alphaMode":"BLEND","doubleSided":true})
    ];
    let motion_info: Vec<Value> = document.motions.iter().map(|m| json!({"bone_count":m.bone_count,"frame_count":m.frame_count,"key_count":m.keys.len(),"morph_count":m.morph_count})).collect();
    let bin_length = builder.bin.len();
    let gltf = json!({
        "asset":{"version":"2.0","generator":"Clash of Legends C3/PVR converter"},
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
        "extras":{"source_c3":source,"coordinate_conversion":"C3 Z-down to glTF Y-up","unit_scale":0.01,"motion_tracks":motion_info}
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
    Ok((glb.len() as u64, mesh_count))
}
