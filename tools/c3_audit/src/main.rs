mod glb;

use sandbox_data::c3::C3Document;
use serde_json::{json, Value};
use std::collections::BTreeSet;
use std::fs;
use std::path::{Path, PathBuf};

fn collect_files(root: &Path, out: &mut Vec<PathBuf>) -> std::io::Result<()> {
    for entry in fs::read_dir(root)? {
        let entry = entry?;
        let path = entry.path();
        if path.is_dir() {
            collect_files(&path, out)?;
        } else if path.extension().and_then(|x| x.to_str()).is_some_and(|x| x.eq_ignore_ascii_case("c3")) {
            out.push(path);
        }
    }
    Ok(())
}

fn category_for(path: &Path) -> Option<&'static str> {
    match path.components().next()?.as_os_str().to_str()? {
        "body" | "npc" => Some("characters"),
        "monster" => Some("monsters"),
        "armet" | "weapon" | "hair" | "cape" | "head" => Some("equipment"),
        "effect" => Some("effects"),
        "ghost" | "misc" => Some("world"),
        _ => None,
    }
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args: Vec<String> = std::env::args().collect();
    if args.len() < 5 {
        return Err("usage: clash-c3-audit <c3-root> <pvr-png-root> <glb-output-root> <audit-json>".into());
    }
    let root = PathBuf::from(&args[1]);
    let pvr_root = PathBuf::from(&args[2]);
    let glb_root = PathBuf::from(&args[3]);
    let output = PathBuf::from(&args[4]);
    let mut files = Vec::new();
    collect_files(&root, &mut files)?;
    files.sort();
    let mut parsed = Vec::new();
    let mut failed = Vec::new();
    let mut converted = Vec::new();
    let mut skipped = Vec::new();
    let mut total_vertices = 0_u64;
    let mut total_triangles = 0_u64;
    let mut total_motions = 0_u64;
    for path in &files {
        let bytes = fs::read(path)?;
        let relative = path.strip_prefix(&root)?.to_string_lossy().replace('\\', "/");
        match C3Document::parse(&bytes) {
            Ok(document) => {
                let mut textures = BTreeSet::new();
                let mut meshes = Vec::new();
                let mut vertices = 0_u64;
                let mut triangles = 0_u64;
                for mesh in &document.meshes {
                    vertices += mesh.vertices.len() as u64;
                    triangles += ((mesh.opaque_indices.len() + mesh.alpha_indices.len()) / 3) as u64;
                    if !mesh.texture_name.trim().is_empty() {
                        textures.insert(mesh.texture_name.clone());
                    }
                    meshes.push(json!({
                        "name": mesh.name,
                        "vertices": mesh.vertices.len(),
                        "opaque_triangles": mesh.opaque_indices.len() / 3,
                        "alpha_triangles": mesh.alpha_indices.len() / 3,
                        "texture_name": mesh.texture_name,
                        "texture_rows": mesh.texture_rows,
                        "bounds_minimum": [mesh.bounds_minimum.x, mesh.bounds_minimum.y, mesh.bounds_minimum.z],
                        "bounds_maximum": [mesh.bounds_maximum.x, mesh.bounds_maximum.y, mesh.bounds_maximum.z],
                        "skinned_vertices": mesh.vertices.iter().filter(|v| v.bone_weights[0] > 0.0 || v.bone_weights[1] > 0.0).count()
                    }));
                }
                total_vertices += vertices;
                total_triangles += triangles;
                total_motions += document.motions.len() as u64;
                let motion_details: Vec<Value> = document.motions.iter().map(|m| json!({"bone_count":m.bone_count,"frame_count":m.frame_count,"key_count":m.keys.len(),"morph_count":m.morph_count})).collect();
                parsed.push(json!({
                    "path": relative,
                    "size_bytes": bytes.len(),
                    "version": document.version,
                    "mesh_count": document.meshes.len(),
                    "motion_count": document.motions.len(),
                    "motion_details": motion_details,
                    "vertex_count": vertices,
                    "triangle_count": triangles,
                    "textures": textures.into_iter().collect::<Vec<_>>(),
                    "meshes": meshes,
                    "unknown_chunks": document.unknown_chunks.iter().map(|c| String::from_utf8_lossy(&c.tag).to_string()).collect::<Vec<_>>()
                }));
                let rel_path = Path::new(&relative);
                let inner = rel_path.strip_prefix("netdragon/c31/c3").unwrap_or(rel_path);
                if let Some(category) = category_for(inner) {
                    let texture_path = pvr_root.join(rel_path.with_extension("png"));
                    if texture_path.is_file() && !document.meshes.is_empty() {
                        let texture_bytes = fs::read(&texture_path)?;
                        let output_relative = Path::new(category).join("c3").join(inner.with_extension("glb"));
                        let output_path = glb_root.join(&output_relative);
                        match glb::export_document(&document, &texture_bytes, &relative, &output_path) {
                            Ok((glb_bytes, mesh_count)) => converted.push(json!({"source":relative,"output":output_relative.to_string_lossy().replace('\\',"/"),"texture":texture_path.to_string_lossy(),"glb_bytes":glb_bytes,"mesh_count":mesh_count,"motion_count":document.motions.len()})),
                            Err(error) => skipped.push(json!({"source":relative,"reason":error.to_string()})),
                        }
                    } else {
                        skipped.push(json!({"source":relative,"reason":"matching decoded PVR texture or renderable mesh is missing"}));
                    }
                }
            }
            Err(error) => failed.push(json!({"path": relative, "size_bytes": bytes.len(), "error": error.to_string()})),
        }
    }
    let report: Value = json!({
        "format": "Conquer C3 model audit and GLB conversion",
        "source_parser": "Preservation CO Client sandbox-data (Apache-2.0, pinned commit 090541d10d8a7d001fe804dd1c23325c344f861d)",
        "total_files": files.len(),
        "parsed_files": parsed.len(),
        "failed_files": failed.len(),
        "total_meshes": parsed.iter().map(|x| x["mesh_count"].as_u64().unwrap_or(0)).sum::<u64>(),
        "total_vertices": total_vertices,
        "total_triangles": total_triangles,
        "total_motion_tracks": total_motions,
        "converted_models": converted.len(),
        "skipped_models": skipped.len(),
        "models": parsed,
        "failed": failed,
        "converted": converted,
        "skipped": skipped
    });
    if let Some(parent) = output.parent() { fs::create_dir_all(parent)?; }
    fs::write(&output, serde_json::to_vec_pretty(&report)?)?;
    let conversion_path = output.parent().unwrap_or(Path::new(".")).join("c3-conversion-report.json");
    fs::write(&conversion_path, serde_json::to_vec_pretty(&json!({"converted":converted,"skipped":skipped}))?)?;
    println!("C3 audit: {} files, {} parsed, {} failed, {} meshes, {} vertices, {} triangles, {} motion tracks; converted {} GLB models",
        files.len(), parsed.len(), report["failed_files"].as_u64().unwrap_or(0),
        report["total_meshes"].as_u64().unwrap_or(0), total_vertices, total_triangles, total_motions,
        report["converted_models"].as_u64().unwrap_or(0));
    if parsed.is_empty() { return Err("no C3 models parsed successfully".into()); }
    if converted.is_empty() { return Err("no C3 models with matching PVR textures converted".into()); }
    Ok(())
}
