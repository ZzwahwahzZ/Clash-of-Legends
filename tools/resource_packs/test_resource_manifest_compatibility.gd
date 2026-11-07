extends SceneTree

# Regression coverage for the two supported resource distribution generations.

const RESOURCE_MANAGER_SCRIPT = preload("res://scripts/core/ResourcePackManager.gd")
const EXPECTED_APP_ID := "com.zwahwahzz.clashoflegends"
const VALID_RELEASE_TAGS := ["resource-packs-v4", "owned-resource-packs-v1"]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var manager = RESOURCE_MANAGER_SCRIPT.new()
	var package := {
		"package_id": "compatibility-test",
		"file_name": "compatibility-test.pck",
		"download_url": "https://example.invalid/compatibility-test.pck",
		"size_bytes": 64,
		"sha256": "a".repeat(64),
		"godot_version": "4.3",
		"platform": "all"
	}
	for release_tag in VALID_RELEASE_TAGS:
		var candidate := {
			"package_id": EXPECTED_APP_ID,
			"release_tag": release_tag,
			"resource_packages": [package]
		}
		if not bool(manager.call("_accept_manifest", candidate)):
			push_error("Resource manifest compatibility failed for release tag: " + release_tag)
			manager.free()
			quit(1)
			return
		var accepted: Dictionary = manager.get("packages")
		if accepted.size() != 1 or not accepted.has("compatibility-test"):
			push_error("Resource manifest package validation failed for release tag: " + release_tag)
			manager.free()
			quit(1)
			return
	var rejected := {
		"package_id": EXPECTED_APP_ID,
		"release_tag": "unrecognized-release-tag",
		"resource_packages": [package]
	}
	if bool(manager.call("_accept_manifest", rejected)):
		push_error("Resource manifest compatibility accepted an unrecognized release tag.")
		manager.free()
		quit(1)
		return
	manager.free()
	print("RESOURCE MANIFEST COMPATIBILITY PASSED: both supported release tags accepted; unknown tag rejected.")
	quit(0)
