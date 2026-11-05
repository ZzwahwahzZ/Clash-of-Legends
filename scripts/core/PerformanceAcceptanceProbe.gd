extends Node
## Collects real-device frame, physics, rendering and memory telemetry for acceptance testing.

const SAMPLE_INTERVAL := 1.0
const WRITE_INTERVAL := 5
const TARGET_FPS := 30

var elapsed := 0.0
var sample_elapsed := 0.0
var samples: Array[Dictionary] = []
var last_report_path := "user://performance_report.json"

func _ready() -> void:
	set_process(true)
	print("PERFORMANCE PROBE READY | target=", TARGET_FPS, " FPS | report=", last_report_path)

func _process(delta: float) -> void:
	elapsed += delta
	sample_elapsed += delta
	if sample_elapsed < SAMPLE_INTERVAL:
		return
	sample_elapsed = 0.0
	samples.append({
		"fps": Engine.get_frames_per_second(),
		"process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"physics_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		"render_objects": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		"render_primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"static_memory_mb": Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
	})
	if samples.size() >= WRITE_INTERVAL:
		_write_report()
		samples.clear()

func _write_report() -> void:
	if samples.is_empty():
		return
	var fps_values: Array[float] = []
	var process_values: Array[float] = []
	var physics_values: Array[float] = []
	for sample in samples:
		fps_values.append(float(sample.fps))
		process_values.append(float(sample.process_ms))
		physics_values.append(float(sample.physics_ms))
	var total_fps := 0.0
	for value in fps_values:
		total_fps += value
	var report := {
		"schema_version": 1,
		"engine": "Godot 4.3",
		"platform": OS.get_name(),
		"target_fps": TARGET_FPS,
		"sample_count": samples.size(),
		"average_fps": total_fps / float(fps_values.size()),
		"minimum_fps": fps_values.min(),
		"maximum_fps": fps_values.max(),
		"average_process_ms": _average(process_values),
		"average_physics_ms": _average(physics_values),
		"samples": samples,
		"captured_unix_time": Time.get_unix_time_from_system()
	}
	var file := FileAccess.open(last_report_path, FileAccess.WRITE)
	if file == null:
		push_warning("Performance probe could not write report: " + str(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("PERFORMANCE REPORT WRITTEN | avg_fps=", report.average_fps, " | min_fps=", report.minimum_fps, " | memory_mb=", samples[-1].static_memory_mb)

func _average(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for value in values:
		total += value
	return total / float(values.size())
