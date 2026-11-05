extends SceneTree

const PACKS := [
	"animations.pck",
	"audio.pck",
	"characters.pck",
	"effects.pck",
	"equipment.pck",
	"interface.pck",
	"maps.pck",
	"models.pck",
	"monsters.pck",
	"mounts.pck",
	"world.pck",
]

func _initialize() -> void:
	call_deferred("_extract")

func _write_bytes(relative_path: String, bytes: PackedByteArray) -> bool:
	var absolute_path := ProjectSettings.globalize_path("res://" + relative_path)
	var directory := absolute_path.get_base_dir()
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		push_error("PCK extraction: cannot create directory " + directory)
		return false
	var output := FileAccess.open(absolute_path, FileAccess.WRITE)
	if output == null:
		push_error("PCK extraction: cannot write " + absolute_path)
		return false
	output.store_buffer(bytes)
	output.close()
	return true

func _sha256(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	if context.update(bytes) != OK:
		return ""
	return context.finish().hex_encode()

func _extract() -> void:
	var pack_root := "res://build/source_packs/"
	for pack_name in PACKS:
		var pack_path := pack_root + pack_name
		if not FileAccess.file_exists(pack_path):
			push_error("PCK extraction: missing verified source pack " + pack_path)
			quit(1)
			return
		if not ProjectSettings.load_resource_pack(pack_path, true):
			push_error("PCK extraction: Godot could not mount " + pack_name)
			quit(1)
			return
	print("Mounted ", PACKS.size(), " resource-packs-v4 PCK files.")

	var path_file := FileAccess.open("res://build/resource-pck-paths.json", FileAccess.READ)
	if path_file == null:
		push_error("PCK extraction: build/resource-pck-paths.json is missing.")
		quit(1)
		return
	var parser := JSON.new()
	if parser.parse(path_file.get_as_text()) != OK or not parser.data is Array:
		push_error("PCK extraction: staged path list is invalid.")
		path_file.close()
		quit(1)
		return
	path_file.close()

	var entries: Array = parser.data
	var verified_files := 0
	var verified_bytes := 0
	var errors: Array[String] = []
	var sample_lines := [
		"# Source format samples (verified resource-packs-v4 PCK extraction)",
		"Binary formats are represented by SHA-256 provenance and short hex prefixes.",
		"",
	]
	var sample_counts := {}
	var sample_extensions := [".ini", ".scene", ".tme", ".ani", ".dat", ".fui", ".tpd", ".tpi", ".wdb", ".otherdata", ".pul", ".pux", ".dmap", ".c3", ".pvr", ".mjp"]

	for index in range(entries.size()):
		var entry: Dictionary = entries[index]
		var relative_path := str(entry.get("path", ""))
		var expected_size := int(entry.get("size_bytes", -1))
		var expected_hash := str(entry.get("sha256", "")).to_lower()
		if not relative_path.begins_with("resource_stage/") or relative_path.contains(".."):
			errors.append("unsafe path: " + relative_path)
			continue

		var bytes := FileAccess.get_file_as_bytes("res://" + relative_path)
		if bytes.size() != expected_size:
			errors.append("size mismatch: " + relative_path + " expected=" + str(expected_size) + " actual=" + str(bytes.size()))
			continue
		var actual_hash := _sha256(bytes)
		if actual_hash != expected_hash:
			errors.append("SHA-256 mismatch: " + relative_path)
			continue
		if not _write_bytes(relative_path, bytes):
			errors.append("write failed: " + relative_path)
			continue

		verified_files += 1
		verified_bytes += bytes.size()
		if index % 500 == 0:
			print("PCK extraction progress: ", index + 1, "/", entries.size(), " files; verified ", verified_files)

		var source := str(entry.get("source", "")).replace("\\", "/")
		var source_parts := source.split("!")
		var inner_path := source_parts[source_parts.size() - 1] if not source_parts.is_empty() else relative_path
		var extension := inner_path.get_extension().to_lower()
		if extension in sample_extensions and int(sample_counts.get(extension, 0)) < 2:
			sample_counts[extension] = int(sample_counts.get(extension, 0)) + 1
			var sample := bytes.slice(0, mini(bytes.size(), 96))
			sample_lines.append("## " + extension + " | " + source + " | " + relative_path + " | " + str(bytes.size()) + " bytes")
			sample_lines.append("HEX: " + sample.hex_encode())
			sample_lines.append("ASCII: " + sample.slice(0, mini(sample.size(), 32)).get_string_from_ascii())
			sample_lines.append("")

	# The catalog is generated after the source index and is therefore not listed in it.
	var catalog_path := "resource_stage/world/resource_catalog.json"
	if FileAccess.file_exists("res://" + catalog_path):
		var catalog_bytes := FileAccess.get_file_as_bytes("res://" + catalog_path)
		if not _write_bytes(catalog_path, catalog_bytes):
			errors.append("resource catalog write failed")
	else:
		errors.append("resource_stage/world/resource_catalog.json is missing from world.pck")

	var sample_absolute := ProjectSettings.globalize_path("res://reports/source-format-samples.txt")
	var sample_file := FileAccess.open(sample_absolute, FileAccess.WRITE)
	if sample_file != null:
		sample_file.store_string("\n".join(sample_lines) + "\n")
		sample_file.close()
	else:
		errors.append("could not write source-format-samples.txt")

	var audit_path := "res://reports/source-archive-extension-audit.json"
	var audit_file := FileAccess.open(audit_path, FileAccess.READ)
	var audit_data: Dictionary = {}
	if audit_file != null:
		var audit_parser := JSON.new()
		if audit_parser.parse(audit_file.get_as_text()) == OK and audit_parser.data is Dictionary:
			audit_data = audit_parser.data
		audit_file.close()
	audit_data["pck_extraction"] = {
		"baseline_release": "resource-packs-v4",
		"pck_files": PACKS,
		"expected_files": entries.size(),
		"verified_files": verified_files,
		"verified_bytes": verified_bytes,
		"errors": errors,
	}
	var audit_output := FileAccess.open(ProjectSettings.globalize_path(audit_path), FileAccess.WRITE)
	if audit_output != null:
		audit_output.store_string(JSON.stringify(audit_data, "\t") + "\n")
		audit_output.close()
	else:
		errors.append("could not update source archive audit report")

	var report := {
		"baseline_release": "resource-packs-v4",
		"pck_files": PACKS,
		"expected_files": entries.size(),
		"verified_files": verified_files,
		"verified_bytes": verified_bytes,
		"errors": errors,
	}
	var report_file := FileAccess.open(ProjectSettings.globalize_path("res://reports/pck-extraction-report.json"), FileAccess.WRITE)
	if report_file != null:
		report_file.store_string(JSON.stringify(report, "\t") + "\n")
		report_file.close()

	print("PCK extraction complete: ", verified_files, "/", entries.size(), " files; ", verified_bytes, " bytes; errors=", errors.size())
	if not errors.is_empty() or verified_files != entries.size():
		for error in errors.slice(0, mini(errors.size(), 40)):
			push_error(str(error))
		quit(1)
	else:
		quit(0)
