use sandbox_data::map::{DMap, GameMapCatalog};
use serde_json::{json, Value};
use std::collections::BTreeMap;
use std::fs;
use std::path::{Path, PathBuf};

fn collect_files(root: &Path, extension: &str, out: &mut Vec<PathBuf>) -> std::io::Result<()> {
    if !root.exists() { return Ok(()); }
    for entry in fs::read_dir(root)? {
        let path = entry?.path();
        if path.is_dir() {
            collect_files(&path, extension, out)?;
        } else if path.extension().and_then(|x| x.to_str()).is_some_and(|x| x.eq_ignore_ascii_case(extension)) {
            out.push(path);
        }
    }
    Ok(())
}


fn deduplicate_game_map_records(bytes: &[u8]) -> Result<(Vec<u8>, usize), String> {
    if bytes.len() < 4 { return Err("GameMap.dat is shorter than its record count".to_owned()); }
    let read_u32 = |offset: usize| -> Result<u32, String> {
        let slice = bytes.get(offset..offset + 4).ok_or_else(|| "truncated GameMap.dat field".to_owned())?;
        Ok(u32::from_le_bytes([slice[0], slice[1], slice[2], slice[3]]))
    };
    let count = read_u32(0)? as usize;
    if count > 1_000_000 { return Err(format!("unreasonable GameMap.dat record count: {count}")); }
    let mut cursor = 4usize;
    let mut output = Vec::new();
    let mut seen = std::collections::HashSet::new();
    let mut duplicates = 0usize;
    let mut kept = Vec::new();
    for _ in 0..count {
        let id = read_u32(cursor)?;
        cursor += 4;
        let path_len = read_u32(cursor)? as usize;
        cursor += 4;
        if path_len == 0 || path_len > 512 { return Err(format!("invalid GameMap.dat path length {path_len}")); }
        let path_end = cursor.checked_add(path_len).ok_or_else(|| "GameMap.dat path overflow".to_owned())?;
        let path = bytes.get(cursor..path_end).ok_or_else(|| "truncated GameMap.dat path".to_owned())?;
        cursor = path_end;
        let tile_end = cursor.checked_add(4).ok_or_else(|| "GameMap.dat tile size overflow".to_owned())?;
        let tile = bytes.get(cursor..tile_end).ok_or_else(|| "truncated GameMap.dat tile size".to_owned())?;
        cursor = tile_end;
        if seen.insert(id) {
            kept.push((id, path.to_vec(), tile.to_vec()));
        } else {
            duplicates += 1;
        }
    }
    if cursor != bytes.len() { return Err(format!("GameMap.dat has {} trailing bytes", bytes.len() - cursor)); }
    output.extend_from_slice(&(kept.len() as u32).to_le_bytes());
    for (id, path, tile) in kept {
        output.extend_from_slice(&id.to_le_bytes());
        output.extend_from_slice(&(path.len() as u32).to_le_bytes());
        output.extend_from_slice(&path);
        output.extend_from_slice(&tile);
    }
    Ok((output, duplicates))
}

fn normalized_path_stem(value: &str) -> String {
    let normalized = value.replace('\\', "/").to_ascii_lowercase();
    Path::new(&normalized)
        .file_stem()
        .and_then(|stem| stem.to_str())
        .unwrap_or("")
        .to_owned()
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args: Vec<String> = std::env::args().collect();
    if args.len() < 3 {
        return Err("usage: audit_maps <resource-stage-root> <output-json>".into());
    }
    let root = PathBuf::from(&args[1]);
    let output = PathBuf::from(&args[2]);
    let mut dmaps = Vec::new();
    collect_files(&root, "dmap", &mut dmaps)?;
    dmaps.sort();

    let mut catalog: Option<GameMapCatalog> = None;
    let mut catalog_source: Option<String> = None;
    let mut catalog_error: Option<String> = None;
    let mut duplicate_catalog_records = 0usize;
    let mut dat_files = Vec::new();
    collect_files(&root, "dat", &mut dat_files)?;
    let mut catalog_candidates: Vec<PathBuf> = dat_files.into_iter().filter(|path| {
        path.file_name().and_then(|x| x.to_str()).is_some_and(|name| name.eq_ignore_ascii_case("gamemap.dat"))
    }).collect();
    catalog_candidates.sort();
    for path in &catalog_candidates {
        let relative = path.strip_prefix(&root).unwrap_or(path).to_string_lossy().replace('\\', "/");
        match fs::read(path).map_err(|error| error.to_string()).and_then(|bytes| deduplicate_game_map_records(&bytes)) {
            Ok((deduplicated, duplicates)) => match GameMapCatalog::parse(&deduplicated) {
                Ok(parsed) => {
                    catalog_source = Some(relative);
                    duplicate_catalog_records = duplicates;
                    catalog = Some(parsed);
                    break;
                }
                Err(error) => catalog_error = Some(error.to_string()),
            },
            Err(error) => catalog_error = Some(error),
        }
    }
    let catalog_candidate_names: Vec<String> = catalog_candidates.iter().map(|path| path.strip_prefix(&root).unwrap_or(path).to_string_lossy().replace('\\', "/")).collect();

    let mut records = Vec::new();
    let mut failed = Vec::new();
    let mut surface_totals: BTreeMap<String, u64> = BTreeMap::new();
    let mut total_cells = 0_u64;
    for path in &dmaps {
        let bytes = fs::read(path)?;
        let relative = path.strip_prefix(&root).unwrap_or(path).to_string_lossy().replace('\\', "/");
        match DMap::parse(&bytes) {
            Ok(map) => {
                let mut elevations: Vec<i16> = map.cells.iter().map(|cell| cell.elevation).collect();
                elevations.sort_unstable();
                let min_elevation = elevations.first().copied().unwrap_or(0);
                let max_elevation = elevations.last().copied().unwrap_or(0);
                let mut surfaces: BTreeMap<String, u64> = BTreeMap::new();
                let mut access: BTreeMap<String, u64> = BTreeMap::new();
                for cell in &map.cells {
                    *surfaces.entry(cell.surface.to_string()).or_default() += 1;
                    *access.entry(cell.access.to_string()).or_default() += 1;
                    *surface_totals.entry(cell.surface.to_string()).or_default() += 1;
                }
                total_cells += map.cells.len() as u64;
                let relative_normalized = relative.replace('\\', "/").to_ascii_lowercase();
                let mut exact_map_ids: Vec<u32> = catalog.as_ref().map(|c| c.records().filter(|r| {
                    let wanted = r.dmap_path.as_str().replace('\\', "/").to_ascii_lowercase();
                    relative_normalized.ends_with(&wanted)
                }).map(|r| r.id).collect()).unwrap_or_default();
                exact_map_ids.sort_unstable();
                exact_map_ids.dedup();
                let (map_id, map_id_match_method) = if exact_map_ids.len() == 1 {
                    (Some(exact_map_ids[0]), "exact_path")
                } else if exact_map_ids.len() > 1 {
                    (None, "ambiguous_exact_path")
                } else {
                    let relative_stem = normalized_path_stem(&relative);
                    let mut stem_map_ids: Vec<u32> = catalog.as_ref().map(|c| c.records().filter(|r| {
                        normalized_path_stem(r.dmap_path.as_str()) == relative_stem
                    }).map(|r| r.id).collect()).unwrap_or_default();
                    stem_map_ids.sort_unstable();
                    stem_map_ids.dedup();
                    if stem_map_ids.len() == 1 {
                        (Some(stem_map_ids[0]), "unique_filename_stem")
                    } else if stem_map_ids.len() > 1 {
                        (None, "ambiguous_filename_stem")
                    } else {
                        (None, "unmatched")
                    }
                };
                records.push(json!({
                    "path": relative,
                    "map_id": map_id,
                    "map_id_match_method": map_id_match_method,
                    "width": map.width,
                    "height": map.height,
                    "cell_count": map.cells.len(),
                    "elevation_min": min_elevation,
                    "elevation_max": max_elevation,
                    "surface_distribution": surfaces,
                    "access_distribution": access,
                    "portal_count": map.portals.len(),
                    "scene_object_count": map.scene_objects.len(),
                    "terrain_object_count": map.terrain_objects.len(),
                    "effect_object_count": map.effect_objects.len(),
                    "sound_object_count": map.sound_objects.len(),
                    "puzzle_path": map.puzzle_path.as_str(),
                    "additional_puzzle_layers": map.additional_puzzle_layers.len()
                }));
            }
            Err(error) => failed.push(json!({"path":relative,"error":error.to_string()}))
        }
    }
    let report: Value = json!({
        "format":"Conquer DMap terrain and scene audit",
        "total_dmap_files":dmaps.len(),
        "parsed_maps":records.len(),
        "failed_maps":failed.len(),
        "game_map_catalog_records":catalog.as_ref().map_or(0, |c| c.len()),
        "game_map_catalog_source":catalog_source,
        "game_map_catalog_error":catalog_error,
        "game_map_catalog_candidates":catalog_candidate_names,
        "duplicate_game_map_records_removed":duplicate_catalog_records,
        "total_cells":total_cells,
        "surface_totals":surface_totals,
        "maps":records,
        "failed":failed
    });
    for map in &records {
        let map_path = map["path"].as_str().unwrap_or("");
        let lower = map_path.to_ascii_lowercase();
        if ["plain", "twin", "city", "market", "birth", "desert", "arena", "forest"].iter().any(|key| lower.contains(key)) {
            println!("DMAP CANDIDATE: path={} id={} size={}x{} elevation={}..{} cells={} puzzle={}",
                map_path,
                map["map_id"].as_u64().map_or_else(|| "unknown".to_owned(), |id| id.to_string()),
                map["width"], map["height"], map["elevation_min"], map["elevation_max"], map["cell_count"], map["puzzle_path"]);
        }
    }
    if let Some(parent) = output.parent() { fs::create_dir_all(parent)?; }
    fs::write(&output, serde_json::to_vec_pretty(&report)?)?;
    println!("DMap audit: {} files, {} parsed, {} failed, {} cells; GameMap catalog records={}",
        dmaps.len(), report["parsed_maps"].as_u64().unwrap_or(0),
        report["failed_maps"].as_u64().unwrap_or(0), total_cells,
        report["game_map_catalog_records"].as_u64().unwrap_or(0));
    println!("GameMap catalog source={:?} parse_error={:?} duplicate_records_removed={} candidates={:?}", catalog_source, catalog_error, duplicate_catalog_records, catalog_candidate_names);
    if records.is_empty() { return Err("no DMap files parsed successfully".into()); }
    Ok(())
}
