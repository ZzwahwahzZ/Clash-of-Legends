mod glb;
mod skinned_glb;

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

fn c3_inner_path(path: &Path) -> PathBuf {
    let components: Vec<_> = path.components().collect();
    if let Some(index) = components.iter().rposition(|component| component.as_os_str() == "c3") {
        components[index + 1..].iter().collect()
    } else {
        path.to_path_buf()
    }
}

fn category_for(path: &Path) -> Option<&'static str> {
    match path.components().next()?.as_os_str().to_str()? {
        "body" | "npc" => Some("characters"),
        "monster" => Some("monsters"),
        "armet" | "weapon" | "hair" | "cape" | "head" => Some("equipment"),
        "mount" | "horse" | "pet" | "ride" => Some("mounts"),
        "effect" => Some("effects"),
        "ghost" | "misc" => Some("world"),
        _ => None,
    }
}

fn parse_motion_path_key(path: &str) -> Option<(u32, u32, u32)> {
    let components: Vec<&str> = path.split('/').collect();
    let c3_index = components.iter().position(|part| part.eq_ignore_ascii_case("c3"))?;
    let look = components.get(c3_index + 1)?.parse::<u32>().ok()?;
    let weapon = components.get(c3_index + 2)?.parse::<u32>().ok()?;
    let action_name = Path::new(components.get(c3_index + 3)?).file_stem()?.to_str()?;
    let action = action_name.parse::<u32>().ok()?;
    Some((look, weapon, action))
}

fn parse_body_model_look(path: &str) -> Option<u32> {
    if !path.to_ascii_lowercase().contains("/c3/body/") {
        return None;
    }
    let model_id = Path::new(path).file_stem()?.to_str()?.parse::<u32>().ok()?;
    Some(model_id / 1_000_000)
}

fn action_name_candidate(action: u32) -> Option<&'static str> {
    match action {
        100 => Some("standby"),
        101 => Some("rest"),
        110 | 111 => Some("walk"),
        120 | 121 => Some("run"),
        130 => Some("jump"),
        190 => Some("wave"),
        _ => None,
    }
}

fn motion_signature_matches(model: &[u32], action: &[u32]) -> bool {
    !model.is_empty() && model == action
}

fn has_valid_mesh_bone_indices(document: &C3Document) -> bool {
    if document.meshes.is_empty() || document.meshes.len() != document.motions.len() {
        return false;
    }
    document.meshes.iter().zip(document.motions.iter()).all(|(mesh, motion)| {
        mesh.vertices.iter().all(|vertex| {
            (0..2).all(|influence| {
                vertex.bone_weights[influence] <= 0.0
                    || vertex.bone_indices[influence] < motion.bone_count
            })
        })
    })
}

#[cfg(test)]
mod motion_pairing_tests {
    use super::*;

    #[test]
    fn accepts_only_exact_nonempty_bone_count_signatures() {
        assert!(motion_signature_matches(&[66, 1, 1], &[66, 1, 1]));
        assert!(!motion_signature_matches(&[66, 1, 1], &[66, 1]));
        assert!(!motion_signature_matches(&[66, 1, 1], &[66, 2, 1]));
        assert!(!motion_signature_matches(&[], &[]));
    }

    #[test]
    fn parses_motion_path_as_look_weapon_action_without_guessing_names() {
        assert_eq!(parse_motion_path_key("netdragon/c31/c3/0007/500/100.c3"), Some((7, 500, 100)));
        assert_eq!(parse_motion_path_key("netdragon/c31/c3/1008/620/121.c3"), Some((1008, 620, 121)));
        assert_eq!(parse_motion_path_key("netdragon/c31/c3/weaponmotion/data.c3"), None);
    }

    #[test]
    fn derives_body_look_from_numeric_model_id() {
        assert_eq!(parse_body_model_look("netdragon/c31/c3/body/7130000.c3"), Some(7));
        assert_eq!(parse_body_model_look("netdragon/c31/c3/body/8130000.c3"), Some(8));
        assert_eq!(parse_body_model_look("netdragon/c31/c3/head/7000000.c3"), None);
    }

    #[test]
    fn labels_common_mobile_action_tokens_as_reference_candidates() {
        assert_eq!(action_name_candidate(100), Some("standby"));
        assert_eq!(action_name_candidate(110), Some("walk"));
        assert_eq!(action_name_candidate(120), Some("run"));
        assert_eq!(action_name_candidate(999), None);
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
    let mut motion_only_documents: Vec<(String, Vec<u32>, Vec<u32>, Option<(u32, u32, u32)>)> = Vec::new();
    let mut model_motion_signatures: Vec<(String, Vec<u32>, Option<u32>)> = Vec::new();
    let mut total_vertices = 0_u64;
    let mut total_triangles = 0_u64;
    let mut total_motion_chunks = 0_u64;
    let mut total_animated_meshes = 0_u64;
    for path in &files {
        let bytes = fs::read(path)?;
        let relative = path.strip_prefix(&root)?.to_string_lossy().replace('\\', "/");
        match C3Document::parse(&bytes) {
            Ok(document) => {
                let motion_signature: Vec<u32> = document.motions.iter().map(|motion| motion.bone_count).collect();
                let frame_signature: Vec<u32> = document.motions.iter().map(|motion| motion.frame_count).collect();
                if document.meshes.is_empty() && !document.motions.is_empty() {
                    motion_only_documents.push((relative.clone(), motion_signature.clone(), frame_signature, parse_motion_path_key(&relative)));
                } else if has_valid_mesh_bone_indices(&document)
                    && motion_signature.len() == document.meshes.len()
                {
                    model_motion_signatures.push((relative.clone(), motion_signature.clone(), parse_body_model_look(&relative)));
                }
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
                total_motion_chunks += document.motions.len() as u64;
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
                let inner = c3_inner_path(rel_path);
                if let Some(category) = category_for(&inner) {
                    let texture_path = pvr_root.join(rel_path.with_extension("png"));
                    if texture_path.is_file() && !document.meshes.is_empty() {
                        let texture_bytes = fs::read(&texture_path)?;
                        let output_relative = Path::new(category).join("c3").join(inner.with_extension("glb"));
                        let output_path = glb_root.join(&output_relative);
                        match glb::export_document(&document, &texture_bytes, &relative, &output_path) {
                            Ok((glb_bytes, mesh_count, animated_mesh_count)) => {
                                total_animated_meshes += animated_mesh_count as u64;
                                converted.push(json!({
                                    "source":relative,
                                    "output":output_relative.to_string_lossy().replace('\\',"/"),
                                    "texture":texture_path.to_string_lossy(),
                                    "glb_bytes":glb_bytes,
                                    "mesh_count":mesh_count,
                                    "motion_chunk_count":document.motions.len(),
                                    "animated_mesh_count":animated_mesh_count
                                }));
                            },
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
    // Produce a small proof-of-concept set by applying separate motion-only C3
    // clips to one male and one female base body. These remain audit-only GLBs under
    // build/c3-glb/motion-poc and are intentionally excluded from runtime PCK merge.
    let mut external_motion_poc: Vec<Value> = Vec::new();
    let mut skeletal_motion_poc: Vec<Value> = Vec::new();
    for (model_id, look) in [(7130000_u32, 7_u32), (8133010_u32, 8_u32)] {
        let body_suffix = format!("/c3/body/{model_id}.c3");
        let Some(body_path) = files.iter().find(|path| path.to_string_lossy().replace('\\', "/").ends_with(&body_suffix)) else {
            external_motion_poc.push(json!({"model_id":model_id,"status":"SKIPPED","reason":"base body C3 file not found"}));
            continue;
        };
        let body_relative = body_path.strip_prefix(&root).unwrap_or(body_path).to_string_lossy().replace('\\', "/");
        let texture_path = pvr_root.join(Path::new(&body_relative).with_extension("png"));
        if !texture_path.is_file() {
            external_motion_poc.push(json!({"model_id":model_id,"status":"SKIPPED","reason":"decoded body PVR texture not found","body_source":body_relative}));
            continue;
        }
        let body_bytes = fs::read(body_path)?;
        let body_document = match C3Document::parse(&body_bytes) {
            Ok(document) => document,
            Err(error) => {
                external_motion_poc.push(json!({"model_id":model_id,"status":"SKIPPED","reason":format!("base body parse failed: {error}")}));
                continue;
            }
        };
        let texture_bytes = fs::read(&texture_path)?;
        for (weapon, action) in [(500_u32, 100_u32), (500_u32, 110_u32), (500_u32, 120_u32)] {
            let motion_suffix = format!("/c3/{look:04}/{weapon:03}/{action}.c3");
            let Some(motion_path) = files.iter().find(|path| path.to_string_lossy().replace('\\', "/").ends_with(&motion_suffix)) else {
                external_motion_poc.push(json!({"model_id":model_id,"look":look,"weapon":weapon,"action":action,"status":"SKIPPED","reason":"motion-only C3 file not found"}));
                continue;
            };
            let motion_relative = motion_path.strip_prefix(&root).unwrap_or(motion_path).to_string_lossy().replace('\\', "/");
            let motion_key = parse_motion_path_key(&motion_relative);
            let motion_bytes = fs::read(motion_path)?;
            let motion_document = match C3Document::parse(&motion_bytes) {
                Ok(document) => document,
                Err(error) => {
                    external_motion_poc.push(json!({"model_id":model_id,"motion_source":motion_relative,"status":"SKIPPED","reason":format!("motion C3 parse failed: {error}")}));
                    continue;
                }
            };
            let body_signature: Vec<u32> = body_document.motions.iter().map(|motion| motion.bone_count).collect();
            let motion_signature: Vec<u32> = motion_document.motions.iter().map(|motion| motion.bone_count).collect();
            if parse_body_model_look(&body_relative) != Some(look)
                || motion_key != Some((look, weapon, action))
                || !motion_signature_matches(&body_signature, &motion_signature)
            {
                external_motion_poc.push(json!({"model_id":model_id,"motion_source":motion_relative,"status":"REJECTED","reason":"look/action path or exact per-mesh bone-count signature mismatch"}));
                continue;
            }
            let output_relative = Path::new("motion-poc").join(format!("look{look}_model{model_id}_weapon{weapon}_action{action}.glb"));
            let output_path = glb_root.join(&output_relative);
            if let Some(parent) = output_path.parent() { fs::create_dir_all(parent)?; }
            let source_pair = format!("{body_relative} + {motion_relative}");
            match glb::export_document_with_external_motion(
                &body_document, &motion_document, &texture_bytes, &source_pair, &output_path
            ) {
                Ok((glb_bytes, mesh_count, animated_mesh_count)) => {
                    total_animated_meshes += animated_mesh_count as u64;
                    converted.push(json!({
                        "source":body_relative,
                        "external_motion_source":motion_relative,
                        "output":output_relative.to_string_lossy().replace('\\', "/"),
                        "texture":texture_path.to_string_lossy(),
                        "glb_bytes":glb_bytes,
                        "mesh_count":mesh_count,
                        "motion_chunk_count":motion_document.motions.len(),
                        "animated_mesh_count":animated_mesh_count,
                        "motion_poc":true
                    }));
                    external_motion_poc.push(json!({
                        "model_id":model_id,"look":look,"weapon":weapon,"action":action,
                        "action_name_candidate":action_name_candidate(action),
                        "body_source":body_relative,"motion_source":motion_relative,
                        "output":output_relative.to_string_lossy().replace('\\', "/"),
                        "mesh_count":mesh_count,"animated_mesh_count":animated_mesh_count,
                        "status":"EXPORTED_PENDING_GODOT_IMPORT_VALIDATION"
                    }));
                    if let Some(body_mesh_index) = body_document.meshes.iter().position(|mesh| mesh.name.eq_ignore_ascii_case("v_body")) {
                        let skinned_document = C3Document {
                            version: body_document.version.clone(),
                            meshes: vec![body_document.meshes[body_mesh_index].clone()],
                            motions: vec![motion_document.motions[body_mesh_index].clone()],
                            unknown_chunks: Vec::new(),
                        };
                        let skinned_relative = Path::new("motion-poc-skinned").join(format!("look{look}_model{model_id}_weapon{weapon}_action{action}.glb"));
                        let skinned_path = glb_root.join(&skinned_relative);
                        let skinned_source = format!("{body_relative} + {motion_relative} [v_body only]");
                        match skinned_glb::export_document(&skinned_document, &texture_bytes, &skinned_source, &skinned_path) {
                            Ok((skinned_bytes, skinned_meshes, skinned_animated_meshes)) => {
                                skeletal_motion_poc.push(json!({
                                    "model_id":model_id,"look":look,"weapon":weapon,"action":action,
                                    "output":skinned_relative.to_string_lossy().replace('\\', "/"),
                                    "glb_bytes":skinned_bytes,"mesh_count":skinned_meshes,
                                    "animated_mesh_count":skinned_animated_meshes,
                                    "status":"EXPORTED_PENDING_GODOT_SKELETON_VALIDATION"
                                }));
                            },
                            Err(error) => skeletal_motion_poc.push(json!({
                                "model_id":model_id,"look":look,"weapon":weapon,"action":action,
                                "status":"REJECTED","reason":error.to_string()
                            }))
                        }
                    } else {
                        skeletal_motion_poc.push(json!({
                            "model_id":model_id,"look":look,"weapon":weapon,"action":action,
                            "status":"REJECTED","reason":"base C3 document has no v_body mesh"
                        }));
                    }
                },
                Err(error) => external_motion_poc.push(json!({
                    "model_id":model_id,"motion_source":motion_relative,"status":"REJECTED",
                    "reason":error.to_string()
                })),
            }
        }
    }

    println!("C3 SKELETAL EXPORT RESULTS: {}", serde_json::to_string(&skeletal_motion_poc)?);

    // Motion-only C3 documents contain action data but no PHY geometry. Match them
    // conservatively against renderable model files by exact per-mesh bone-count
    // signature and valid vertex bone indices. This is a structural candidate list,
    // not proof of semantic action ID, rig identity, or visual correctness.
    let motion_pairing_report: Vec<Value> = motion_only_documents.iter().map(|(motion_path, signature, frames, path_key)| {
        let candidates: Vec<String> = model_motion_signatures.iter()
            .filter(|(_, model_signature, _)| motion_signature_matches(model_signature, signature))
            .map(|(model_path, _, _)| model_path.clone())
            .collect();
        let body_candidates: Vec<(String, &'static str)> = if let Some((motion_look, _, _)) = path_key {
            model_motion_signatures.iter()
                .filter(|(_, model_signature, body_look)| {
                    motion_signature_matches(model_signature, signature)
                        && body_look.is_some_and(|look| look == *motion_look || *motion_look % 1000 == look)
                })
                .map(|(model_path, _, body_look)| {
                    let relation = if body_look == &Some(path_key.unwrap().0) { "direct_numeric_look_match" } else { "suffix_look_candidate_unverified" };
                    (model_path.clone(), relation)
                })
                .collect()
        } else { Vec::new() };
        json!({
            "motion_only_path": motion_path,
            "motion_path_key": path_key.map(|(look, weapon, action)| json!({"look_token":look,"weapon_token":weapon,"action_token":action})),
            "motion_bone_count_signature": signature,
            "motion_frame_count_signature": frames,
            "bone_signature_candidate_model_count": candidates.len(),
            "bone_signature_candidate_model_paths": candidates.iter().take(50).collect::<Vec<_>>(),
            "body_look_candidate_model_count": body_candidates.len(),
            "body_look_candidate_model_paths": body_candidates.iter().take(20).map(|(path, relation)| json!({"path":path,"relation":relation})).collect::<Vec<_>>(),
            "candidate_paths_truncated": candidates.len() > 50 || body_candidates.len() > 20,
            "acceptance": "PATH_KEY_AND_BONE_SIGNATURE_CANDIDATES_ONLY_NOT_RUNTIME_PAIRED"
        })
    }).collect();
    let total_structural_pairs: usize = motion_pairing_report.iter()
        .map(|row| row["bone_signature_candidate_model_count"].as_u64().unwrap_or(0) as usize)
        .sum();
    let uniquely_pairable_motion_files = motion_pairing_report.iter()
        .filter(|row| row["bone_signature_candidate_model_count"].as_u64() == Some(1))
        .count();
    let parsed_motion_path_keys = motion_pairing_report.iter()
        .filter(|row| row["motion_path_key"].is_object())
        .count();
    let body_look_candidate_pairs: usize = motion_pairing_report.iter()
        .map(|row| row["body_look_candidate_model_count"].as_u64().unwrap_or(0) as usize)
        .sum();

    let report: Value = json!({
        "format": "Conquer C3 model audit and GLB conversion",
        "source_parser": "Preservation CO Client sandbox-data (Apache-2.0, pinned commit 090541d10d8a7d001fe804dd1c23325c344f861d)",
        "total_files": files.len(),
        "parsed_files": parsed.len(),
        "failed_files": failed.len(),
        "total_meshes": parsed.iter().map(|x| x["mesh_count"].as_u64().unwrap_or(0)).sum::<u64>(),
        "total_vertices": total_vertices,
        "total_triangles": total_triangles,
        "total_motion_chunks": total_motion_chunks,
        "total_animated_meshes": total_animated_meshes,
        "motion_only_documents": motion_pairing_report.len(),
        "motion_only_structural_candidate_pairs": total_structural_pairs,
        "motion_only_uniquely_pairable_documents": uniquely_pairable_motion_files,
        "motion_only_parsed_path_keys": parsed_motion_path_keys,
        "motion_only_body_look_candidate_pairs": body_look_candidate_pairs,
        "external_motion_poc_count": external_motion_poc.iter().filter(|row| row["status"] == "EXPORTED_PENDING_GODOT_IMPORT_VALIDATION").count(),
        "external_motion_poc": external_motion_poc,
        "skeletal_motion_poc": skeletal_motion_poc,
        "motion_only_pairing_status": "PATH_KEY_AND_BONE_SIGNATURE_CANDIDATES_ONLY_NOT_RUNTIME_PAIRED",
        "motion_only_pairing": motion_pairing_report,
        "converted_models": converted.len(),
        "skipped_models": skipped.len(),
        "models": parsed,
        "failed": failed,
        "converted": converted.clone(),
        "skipped": skipped.clone()
    });
    if let Some(parent) = output.parent() { fs::create_dir_all(parent)?; }
    fs::write(&output, serde_json::to_vec_pretty(&report)?)?;
    let conversion_path = output.parent().unwrap_or(Path::new(".")).join("c3-conversion-report.json");
    fs::write(&conversion_path, serde_json::to_vec_pretty(&json!({"converted":converted,"skipped":skipped}))?)?;
    println!("C3 audit: {} files, {} parsed, {} failed, {} meshes, {} vertices, {} triangles, {} motion chunks, {} animated mesh channels; {} motion-only files, {} structural candidate pairs, {} unique candidates; converted {} GLB models",
        files.len(), parsed.len(), report["failed_files"].as_u64().unwrap_or(0),
        report["total_meshes"].as_u64().unwrap_or(0), total_vertices, total_triangles, total_motion_chunks,
        total_animated_meshes, report["motion_only_documents"].as_u64().unwrap_or(0),
        report["motion_only_structural_candidate_pairs"].as_u64().unwrap_or(0),
        report["motion_only_uniquely_pairable_documents"].as_u64().unwrap_or(0),
        report["converted_models"].as_u64().unwrap_or(0));
    if parsed.is_empty() { return Err("no C3 models parsed successfully".into()); }
    if converted.is_empty() { return Err("no C3 models with matching PVR textures converted".into()); }
    Ok(())
}
