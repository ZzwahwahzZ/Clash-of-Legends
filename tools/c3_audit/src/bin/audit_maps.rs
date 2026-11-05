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
    let mut dat_files = Vec::new();
    collect_files(&root, "dat", &mut dat_files)?;
    for path in dat_files {
        if path.file_name().and_then(|x| x.to_str()).is_some_and(|x| x.eq_ignore_ascii_case("gamemap.dat")) {
            if let Ok(parsed) = GameMapCatalog::parse(&fs::read(&path)?) {
                catalog = Some(parsed);
                break;
            }
        }
    }

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
                let map_id = catalog.as_ref().and_then(|c| c.records().find(|r| {
                    let wanted = r.dmap_path.as_str().to_ascii_lowercase();
                    relative.to_ascii_lowercase().ends_with(&wanted)
                }).map(|r| r.id));
                records.push(json!({
                    "path": relative,
                    "map_id": map_id,
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
    if records.is_empty() { return Err("no DMap files parsed successfully".into()); }
    Ok(())
}
