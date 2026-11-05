extends Node
## Lazy, offline audio playback for the 298 checked-in OGG assets.
## Audio is loaded only when a cue is first requested; missing cues fail silently.

const AUDIO_DIR := "res://assets/audio/extracted/"
const CUE_STEMS := {
	"attack_sword": ["crosssword_m01", "falchion_m01"],
	"attack_axe": ["axe_m01", "axe_m02"],
	"attack_bow": ["bow01", "arrows"],
	"attack_dagger": ["knife_m01", "knife_m03"],
	"attack_unarmed": ["boxing_m01", "boxing_h01"],
	"attack_magic": ["magic003", "casting"],
	"jump": ["jump"],
	"footstep": ["runl", "runr"],
	"hit": ["bruise01", "bruise03"],
	"death": ["bloodsickle"],
	"monster_attack": ["fatbossatc1", "ferocitytiger"],
	"monster_death": ["fatbossatc4", "fatbossatc5"],
	"pickup": ["addpoint", "gathering"],
	"level_up": ["health"],
	"npc_talk": ["qjp_se"],
	"heal": ["health"],
	"buff": ["protect_shield", "manashield"],
	"cast": ["casting"],
}
const CLASS_ATTACK_CUES := {
	"Trojan": "attack_sword",
	"Warrior": "attack_axe",
	"Archer": "attack_bow",
	"Ninja": "attack_dagger",
	"Monk": "attack_unarmed",
	"Pirate": "attack_sword",
	"DragonWarrior": "attack_axe",
	"Windwalker": "attack_dagger",
	"Thunderstriker": "attack_magic",
	"WaterTaoist": "attack_magic",
	"FireTaoist": "attack_magic",
}
const SKILL_STEMS := {
	"trojan_cyclone": "crosssword_m01",
	"trojan_fast_blade": "falchion_m01",
	"warrior_flying_dragon": "sk_warrior_hxdf",
	"warrior_shield_block": "shieldparry",
	"archer_rapid_arrow": "preciseshot",
	"archer_scatter": "arrows",
	"taoist_thunder": "magic003",
	"taoist_heal": "health",
	"ninja_fatal_strike": "shadowdance",
	"monk_whirlwind": "sk_monk_bjgh",
	"pirate_cannon": "pirate_skill_superfire",
}
const MAP_MUSIC := {
	"twin_city": "centralplains",
	"twin_plains": "centralplains",
	"desert_ruins": "music",
	"mountain_summit": "music",
}

var _files_by_stem: Dictionary = {}
var _stream_cache: Dictionary = {}
var _music_player: AudioStreamPlayer
var music_enabled := true
var sfx_enabled := true
var music_volume_db := -12.0
var sfx_volume_db := -6.0

func _ready() -> void:
	_index_audio_files()
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "WorldMusicPlayer"
	_music_player.bus = "Master"
	add_child(_music_player)

func _process(delta: float) -> void:
	for cue in _footstep_cooldowns.keys():
		_footstep_cooldowns[cue] = maxf(0.0, float(_footstep_cooldowns[cue]) - delta)

func _index_audio_files() -> void:
	var directory := DirAccess.open(AUDIO_DIR)
	if directory == null:
		push_warning("GameAudioManager: offline audio directory is not available.")
		return
	for filename in directory.get_files():
		if filename.get_extension().to_lower() != "ogg":
			continue
		_files_by_stem[filename.get_basename().to_lower()] = filename
	print("GameAudioManager: indexed ", _files_by_stem.size(), " offline OGG cues.")

func _resolve_stem(cue_id: String) -> String:
	var requested := cue_id.strip_edges().to_lower()
	var candidates: Array = CUE_STEMS.get(requested, [requested])
	for candidate in candidates:
		var exact := str(candidate).to_lower()
		if _files_by_stem.has(exact):
			return exact
	for candidate in candidates:
		var partial := str(candidate).to_lower()
		for stem in _files_by_stem.keys():
			if str(stem).contains(partial):
				return str(stem)
	return ""

func _load_stream(stem: String) -> AudioStream:
	if _stream_cache.has(stem):
		return _stream_cache[stem] as AudioStream
	if not _files_by_stem.has(stem):
		return null
	var path := AUDIO_DIR.path_join(str(_files_by_stem[stem]))
	var stream := ResourceLoader.load(path) as AudioStream
	if stream:
		_stream_cache[stem] = stream
	return stream

func play_sfx(cue_id: String, source: Node3D = null, volume_offset_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	if not sfx_enabled:
		return
	var stem := _resolve_stem(cue_id)
	if stem.is_empty():
		return
	var stream := _load_stream(stem)
	if stream == null:
		return
	var player: Variant
	if source != null and is_instance_valid(source):
		var spatial := AudioStreamPlayer3D.new()
		spatial.max_distance = 28.0
		spatial.unit_size = 8.0
		spatial.global_position = source.global_position
		var world := get_tree().current_scene
		if world is Node3D:
			world.add_child(spatial)
		else:
			add_child(spatial)
		player = spatial
	else:
		var flat := AudioStreamPlayer.new()
		add_child(flat)
		player = flat
	player.stream = stream
	player.volume_db = sfx_volume_db + volume_offset_db
	player.pitch_scale = clampf(pitch_scale, 0.75, 1.35)
	player.finished.connect(player.queue_free)
	player.play()

func play_player_attack(player: Node3D, target: Node3D = null) -> void:
	var class_id := str(player.get("character_class")) if player != null else "Trojan"
	var cue := str(CLASS_ATTACK_CUES.get(class_id, "attack_sword"))
	play_sfx(cue, target if target and is_instance_valid(target) else player)

func play_skill(skill_id: String, caster: Node3D, target: Node3D = null) -> void:
	var stem := str(SKILL_STEMS.get(skill_id, "casting"))
	play_sfx(stem, target if target and is_instance_valid(target) else caster)

func play_map_music(destination_id: String) -> void:
	var stem := str(MAP_MUSIC.get(destination_id, "centralplains"))
	play_music(stem)

func play_music(stem_or_cue: String) -> void:
	if not music_enabled:
		return
	var stem := _resolve_stem(stem_or_cue)
	if stem.is_empty():
		stem = stem_or_cue.to_lower() if _files_by_stem.has(stem_or_cue.to_lower()) else ""
	if stem.is_empty():
		return
	var stream := _load_stream(stem)
	if stream == null:
		return
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	if _music_player.stream == stream and _music_player.playing:
		return
	_music_player.stream = stream
	_music_player.volume_db = music_volume_db
	_music_player.play()

func stop_music() -> void:
	if _music_player:
		_music_player.stop()

func set_music_enabled(enabled: bool) -> void:
	music_enabled = enabled
	if not enabled:
		stop_music()

func set_sfx_enabled(enabled: bool) -> void:
	sfx_enabled = enabled

func set_music_volume(value: float) -> void:
	music_volume_db = clampf(value, -40.0, 0.0)
	if _music_player:
		_music_player.volume_db = music_volume_db

func set_sfx_volume(value: float) -> void:
	sfx_volume_db = clampf(value, -40.0, 0.0)
