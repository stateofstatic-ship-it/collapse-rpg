class_name Metrics
extends Node
## Frame timing, memory, battery and thermal readouts.
## Frame times come from wall-clock ticks, not the smoothed delta.
## Battery and thermal use Android's BatteryManager and PowerManager
## through JavaClassWrapper (Godot 4.4+), so no Java plugin is needed.

const RING := 600
const THERMAL_NAMES := ["none", "light", "moderate", "SEVERE", "CRITICAL", "EMERGENCY", "SHUTDOWN"]

var ring := PackedFloat32Array()
var ring_i := 0
var last_us := 0
var started_ms := 0

# recording (bench stages)
var rec_on := false
var rec_frames := 0
var rec_sum := 0.0
var rec_list := PackedFloat32Array()
var rec_draws := 0.0
var rec_samples := 0

# slow-changing samples (refreshed each second)
var sample := {}
var sample_t := 0.0

# android
var ctx: Object = null
var battery_mgr: Object = null
var power_mgr: Object = null
var android_error := ""
var battery_start_pct := -1.0
var battery_start_ms := 0
var max_thermal := 0
var world_vp: Viewport = null


func _ready() -> void:
	ring.resize(RING)
	ring.fill(16.7)
	started_ms = Time.get_ticks_msec()
	last_us = Time.get_ticks_usec()
	_init_android()
	_refresh()


func _init_android() -> void:
	if OS.get_name() != "Android":
		android_error = "not Android"
		return
	if not Engine.has_singleton("AndroidRuntime"):
		android_error = "AndroidRuntime missing"
		return
	var rt := Engine.get_singleton("AndroidRuntime")
	ctx = rt.getApplicationContext()
	if ctx == null:
		android_error = "no context"
		return
	battery_mgr = ctx.getSystemService("batterymanager")
	power_mgr = ctx.getSystemService("power")
	if battery_mgr == null or power_mgr == null:
		android_error = "system services unavailable"


func _process(_d: float) -> void:
	var now := Time.get_ticks_usec()
	var ms := float(now - last_us) / 1000.0
	last_us = now
	ring[ring_i] = ms
	ring_i = (ring_i + 1) % RING
	if rec_on:
		rec_frames += 1
		rec_sum += ms
		rec_list.append(ms)
		rec_draws += draw_calls()
	sample_t += _d
	if sample_t >= 1.0:
		sample_t = 0.0
		_refresh()
		if rec_on:
			rec_samples += 1


func draw_calls() -> float:
	var n := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	if world_vp != null:
		n += world_vp.get_render_info(Viewport.RENDER_INFO_TYPE_CANVAS, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
	return n


func _refresh() -> void:
	sample["fps"] = Engine.get_frames_per_second()
	sample["tex_mb"] = Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0
	sample["vid_mb"] = Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0
	sample["static_mb"] = Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
	sample["nodes"] = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	sample["rss_mb"] = _rss_mb()
	var mi := OS.get_memory_info()
	sample["avail_mb"] = float(mi.get("available", -1)) / 1048576.0
	sample["phys_mb"] = float(mi.get("physical", -1)) / 1048576.0
	if world_vp != null:
		sample["gpu_ms"] = RenderingServer.viewport_get_measured_render_time_gpu(world_vp.get_viewport_rid())
		sample["cpu_ms"] = RenderingServer.viewport_get_measured_render_time_cpu(world_vp.get_viewport_rid())
	_refresh_android()


func _rss_mb() -> float:
	var f := FileAccess.open("/proc/self/status", FileAccess.READ)
	if f == null:
		return -1.0
	while not f.eof_reached():
		var line := f.get_line()
		if line.begins_with("VmRSS:"):
			return float(line.split(":")[1].strip_edges().split(" ")[0]) / 1024.0
	return -1.0


func _refresh_android() -> void:
	sample["batt_pct"] = -1.0
	sample["batt_ma"] = 0.0
	sample["drain_pct_h"] = -1.0
	sample["charging"] = false
	sample["thermal"] = -1
	sample["headroom"] = -1.0
	if battery_mgr == null:
		return
	# BATTERY_PROPERTY_CAPACITY = 4, CURRENT_NOW = 2 (microamps), CHARGE_COUNTER = 1 (microamp-hours)
	var pct := float(battery_mgr.getIntProperty(4))
	var cur := float(battery_mgr.getIntProperty(2))
	var cnt := float(battery_mgr.getIntProperty(1))
	sample["batt_pct"] = pct
	sample["batt_ma"] = cur / 1000.0
	sample["charging"] = bool(battery_mgr.isCharging())
	if pct > 0 and cnt > 0 and abs(cur) > 0:
		var full_uah := cnt / (pct / 100.0)
		sample["drain_pct_h"] = abs(cur) / full_uah * 100.0
	if battery_start_pct < 0 and pct > 0:
		battery_start_pct = pct
		battery_start_ms = Time.get_ticks_msec()
	if power_mgr != null:
		var st := int(power_mgr.getCurrentThermalStatus())
		sample["thermal"] = st
		max_thermal = maxi(max_thermal, st)
		sample["headroom"] = float(power_mgr.getThermalHeadroom(10))


func battery_used_pct_per_hour() -> float:
	if battery_start_pct < 0:
		return -1.0
	var hours := float(Time.get_ticks_msec() - battery_start_ms) / 3600000.0
	if hours < 0.05:
		return -1.0
	return (battery_start_pct - float(sample.get("batt_pct", battery_start_pct))) / hours


func window_stats() -> Dictionary:
	var arr := ring.duplicate()
	arr.sort()
	var s := 0.0
	var slow := 0
	for v in arr:
		s += v
		if v > 33.4:
			slow += 1
	return {"avg": s / RING, "p99": arr[int(RING * 0.99)], "worst": arr[RING - 1], "slow_pct": 100.0 * slow / RING}


func start_record() -> void:
	rec_on = true
	rec_frames = 0
	rec_sum = 0.0
	rec_list = PackedFloat32Array()
	rec_draws = 0.0
	rec_samples = 0


func stop_record() -> Dictionary:
	rec_on = false
	if rec_frames == 0:
		return {}
	var arr := rec_list.duplicate()
	arr.sort()
	var slow33 := 0
	var slow17 := 0
	for v in arr:
		if v > 33.4:
			slow33 += 1
		if v > 16.8:
			slow17 += 1
	var n := arr.size()
	return {
		"frames": n,
		"fps": 1000.0 * n / rec_sum,
		"avg_ms": rec_sum / n,
		"p50_ms": arr[n / 2],
		"p99_ms": arr[mini(n - 1, int(n * 0.99))],
		"worst_ms": arr[n - 1],
		"slow33_pct": 100.0 * slow33 / n,
		"over17_pct": 100.0 * slow17 / n,
		"draws": rec_draws / n,
		"tex_mb": sample.get("tex_mb", 0.0),
		"vid_mb": sample.get("vid_mb", 0.0),
		"rss_mb": sample.get("rss_mb", -1.0),
		"thermal": sample.get("thermal", -1),
		"headroom": sample.get("headroom", -1.0),
		"batt_pct": sample.get("batt_pct", -1.0),
		"drain_pct_h": sample.get("drain_pct_h", -1.0),
	}


static func thermal_name(v: int) -> String:
	if v < 0 or v >= THERMAL_NAMES.size():
		return "n/a"
	return THERMAL_NAMES[v]


func device_line() -> String:
	return "%s | %s %s | %s | %s %s | screen %s @ %d dpi" % [
		OS.get_model_name(), OS.get_name(), OS.get_version(), OS.get_processor_name(),
		RenderingServer.get_current_rendering_method() + "/" + RenderingServer.get_current_rendering_driver_name(), RenderingServer.get_video_adapter_name(),
		str(DisplayServer.screen_get_size()), DisplayServer.screen_get_dpi()]


func overlay_text() -> String:
	var w := window_stats()
	var lines: Array[String] = []
	lines.append("FPS %d   frame %.1f ms   1%% worst %.1f   max %.1f   slow>33ms %.1f%%" % [sample.get("fps", 0), w["avg"], w["p99"], w["worst"], w["slow_pct"]])
	lines.append("draws %d   nodes %d   GPU %.1f ms   CPU %.1f ms" % [draw_calls(), sample.get("nodes", 0), sample.get("gpu_ms", 0.0), sample.get("cpu_ms", 0.0)])
	lines.append("RAM %s   textures %.0f MB   video %.0f MB   free %s" % [
		("%.0f MB" % sample["rss_mb"]) if sample.get("rss_mb", -1.0) > 0 else "n/a", sample.get("tex_mb", 0.0), sample.get("vid_mb", 0.0),
		("%.0f MB" % sample["avail_mb"]) if sample.get("avail_mb", -1.0) > 0 else "n/a"])
	if battery_mgr != null:
		var used := battery_used_pct_per_hour()
		lines.append("battery %d%% %s  %.0f mA  ~%.1f %%/h now  %s  heat: %s (headroom %.2f, worst %s)" % [
			sample["batt_pct"], "CHARGING-unplug for test" if sample["charging"] else "", abs(sample["batt_ma"]),
			sample["drain_pct_h"], ("%.1f %%/h measured" % used) if used >= 0 else "",
			thermal_name(sample["thermal"]), sample["headroom"], thermal_name(max_thermal)])
	else:
		lines.append("battery/heat: n/a (%s)" % android_error)
	return "\n".join(lines)
