extends Node
## Device stress test for the collapse RPG (design/chapters/tech.md,
## "week-one stress scene"). Builds the world, the battle mock, the HUD and
## the timed test runs, and writes a plain-text report.

const VERSION := "stress-test 2"
const CYCLES := {
	"chars": [12, 24, 48, 4],
	"layered": [4, 12, 0],
	"lights": [12, 16, 24, 4, 0],
	"rain": [true, false],
	"night": [true, false],
	"scale": [0.67, 1.0],
	"fps_cap": [60, 30, 120],
}
const LABELS := {"chars": "Characters", "layered": "Layered family sprites", "lights": "Lights", "rain": "Rain", "night": "Night", "scale": "World render scale", "fps_cap": "Frame cap"}

var settings := {"chars": 12, "layered": 4, "lights": 12, "rain": true, "night": true, "scale": 0.67, "fps_cap": 60}
var container: SubViewportContainer
var vp: SubViewport
var world: World
var battle: Battle
var metrics: Metrics
var hud: Hud
var in_battle := false
var report := ""
var last_save := {}

# bench state
var bench: Array = []
var bench_i := -1
var bench_t := 0.0
var bench_results: Array = []
var soak := false
var soak_rows: Array = []
var soak_min_t := 0.0
const WARMUP := 3.0


func _ready() -> void:
	container = SubViewportContainer.new()
	container.stretch = true
	container.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(container)
	vp = SubViewport.new()
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR
	container.add_child(vp)
	RenderingServer.viewport_set_measure_render_time(vp.get_viewport_rid(), true)
	world = World.new()
	vp.add_child(world)
	world.build()
	metrics = Metrics.new()
	metrics.world_vp = vp
	add_child(metrics)
	hud = Hud.new()
	add_child(hud)
	hud.setup(self)
	get_viewport().size_changed.connect(_on_resize)
	_apply_all()
	print(metrics.device_line())
	_handle_cmdline()


## Agent checks only: `-- --shot=res://x.png --battle --fast-bench`
func _handle_cmdline() -> void:
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a == "--battle":
			set_battle(true)
		elif a == "--fast-bench":
			start_bench()
			for st in bench:
				st["secs"] = 6.0
		elif a == "--report":
			hud.show_report("")
		elif a.begins_with("--shot="):
			var path := a.substr(7)
			await get_tree().create_timer(4.0).timeout
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(path)
			print("shot saved ", path)
			if not "--fast-bench" in args:
				get_tree().quit()


func _on_resize() -> void:
	var sz := get_viewport().get_visible_rect().size
	var s: float = settings["scale"]
	container.position = Vector2.ZERO
	container.scale = Vector2.ONE / s
	container.size = sz * s
	world.set_view(s, sz.y)
	if battle != null:
		battle.set_view(s, sz.y)


func _apply_all() -> void:
	if world.walkers_node.get_child_count() != settings["chars"] or _layered_count() != settings["layered"]:
		world.set_walkers(settings["chars"], settings["layered"])
	world.set_lights(settings["lights"])
	world.set_rain(settings["rain"])
	world.set_night(settings["night"])
	Engine.max_fps = settings["fps_cap"]
	_on_resize()
	hud.refresh_settings()


func _layered_count() -> int:
	var n := 0
	for w in world.walkers_node.get_children():
		if w.layered:
			n += 1
	return n


func fmt_setting(key: String) -> String:
	var v = settings[key]
	if v is bool:
		return "on" if v else "off"
	if key == "fps_cap":
		return "%d fps" % v
	if key == "scale":
		return "%.2f" % v
	return str(v)


func cycle_setting(key: String) -> void:
	var opts: Array = CYCLES[key]
	var i := opts.find(settings[key])
	settings[key] = opts[(i + 1) % opts.size()]
	_apply_all()


func toggle_mode() -> void:
	set_battle(not in_battle)


func set_battle(on: bool) -> void:
	if on == in_battle:
		return
	in_battle = on
	if on:
		world.process_mode = Node.PROCESS_MODE_DISABLED
		vp.remove_child(world)
		battle = Battle.new()
		vp.add_child(battle)
		battle.log_line.connect(hud.battle_log)
		battle.state_changed.connect(func() -> void: hud.update_battle(battle))
		battle.build()
		battle.camera.make_current()
	else:
		battle.queue_free()
		battle = null
		vp.add_child(world)
		world.process_mode = Node.PROCESS_MODE_INHERIT
		world.camera.make_current()
	hud.set_battle_mode(on)
	_on_resize()
	if battle != null:
		hud.update_battle(battle)


func toggle_auto() -> void:
	if battle == null:
		return
	battle.auto_play = not battle.auto_play
	hud.update_battle(battle)
	if battle.auto_play and battle.active()["team"] == "party" and not battle.busy:
		battle._ai_turn()


# ------------------------------------------------------------------ save / load
func _save_payload() -> Dictionary:
	# Synthetic world state sized like a mid-game save: 400 containers x 12 items,
	# 300 NPC records, faction and rumor tables.
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var containers: Array = []
	for i in 400:
		var items: Array = []
		for j in 12:
			items.append({"id": "item_%d" % rng.randi_range(0, 300), "n": rng.randi_range(1, 20), "cond": rng.randf()})
		containers.append({"id": "c%d" % i, "map": "hillsboro_%d" % (i % 9), "cell": [rng.randi_range(0, 63), rng.randi_range(0, 63)], "items": items, "looted": rng.randf() < 0.3})
	var npcs: Array = []
	for i in 300:
		npcs.append({"id": "npc_%d" % i, "hp": rng.randi_range(1, 40), "standing": rng.randi_range(-100, 100), "flags": ["met", "owes_favor"] if i % 3 == 0 else [], "memory": "Saw the family share water on day %d" % rng.randi_range(1, 90)})
	var d := {
		"version": 1, "build": VERSION, "saved_at": Time.get_datetime_string_from_system(true),
		"settings": settings.duplicate(), "world": world.to_save(),
		"battle": battle.to_save() if battle != null else {},
		"containers": containers, "npcs": npcs,
		"factions": {"talbert_guard": 12, "co_op": 40, "keelson": -20},
	}
	return d


func do_save(quiet := false) -> Dictionary:
	var t0 := Time.get_ticks_usec()
	var d := _save_payload()
	var t1 := Time.get_ticks_usec()
	var f := FileAccess.open_compressed("user://save_test.bin", FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	f.store_var(d)
	f.close()
	var t2 := Time.get_ticks_usec()
	var j := FileAccess.open("user://save_test.json", FileAccess.WRITE)
	j.store_string(JSON.stringify(d))
	j.close()
	var t3 := Time.get_ticks_usec()
	var res := {"build_ms": (t1 - t0) / 1000.0, "bin_ms": (t2 - t1) / 1000.0, "json_ms": (t3 - t2) / 1000.0,
		"bin_kb": _file_kb("user://save_test.bin"), "json_kb": _file_kb("user://save_test.json")}
	last_save = res
	if not quiet:
		hud.show_toast("Saved: build %.1f ms, write %.1f ms (%.0f KB compressed, %.0f KB as JSON)" % [res["build_ms"], res["bin_ms"], res["bin_kb"], res["json_kb"]])
		hud.log_line("Saved game state.")
	return res


func do_load(quiet := false) -> Dictionary:
	if not FileAccess.file_exists("user://save_test.bin"):
		hud.show_toast("No save yet. Tap Save first.")
		return {}
	var t0 := Time.get_ticks_usec()
	var f := FileAccess.open_compressed("user://save_test.bin", FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	var d: Dictionary = f.get_var()
	f.close()
	var t1 := Time.get_ticks_usec()
	world.from_save(d["world"])
	if battle != null and not (d["battle"] as Dictionary).is_empty():
		battle.from_save(d["battle"])
	var t2 := Time.get_ticks_usec()
	var j := FileAccess.get_file_as_string("user://save_test.json")
	var parsed = JSON.parse_string(j)
	var t3 := Time.get_ticks_usec()
	var ok: bool = parsed is Dictionary and (parsed as Dictionary).get("version", 0) == 1
	var res := {"read_ms": (t1 - t0) / 1000.0, "apply_ms": (t2 - t1) / 1000.0, "json_parse_ms": (t3 - t2) / 1000.0, "ok": ok}
	if not quiet:
		hud.show_toast("Loaded: read %.1f ms, apply %.1f ms, JSON parse %.1f ms%s" % [res["read_ms"], res["apply_ms"], res["json_parse_ms"], "" if ok else " (JSON check FAILED)"])
		hud.log_line("Loaded game state.")
	return res


func _file_kb(p: String) -> float:
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null:
		return -1.0
	var n := f.get_length()
	f.close()
	return n / 1024.0


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED and world != null:
		var r := do_save(true)
		FileAccess.open("user://autosave_note.txt", FileAccess.WRITE).store_string("autosave on pause %.1f ms at %s" % [r["build_ms"] + r["bin_ms"], Time.get_datetime_string_from_system()])


# ------------------------------------------------------------------ bench
func start_bench() -> void:
	if bench_i >= 0:
		hud.show_toast("A test is already running.")
		return
	soak = false
	bench = [
		{"name": "A. Full resolution: 12 chars (4 layered), 12 lights, rain, night, 60 cap", "secs": 30.0, "battle": false, "s": {"chars": 12, "layered": 4, "lights": 12, "rain": true, "night": true, "scale": 1.0, "fps_cap": 60}},
		{"name": "B. Phone setting: same at 0.67 scale, 60 cap", "secs": 40.0, "battle": false, "s": {"scale": 0.67}},
		{"name": "C. 0.67 scale, 30 fps cap (battery lever)", "secs": 40.0, "battle": false, "s": {"fps_cap": 30}},
		{"name": "D. 0.67 scale, 6 lights, 60 cap (light cost)", "secs": 30.0, "battle": false, "s": {"lights": 6, "fps_cap": 60}},
		{"name": "E. 0.67 scale, no rain, 60 cap (rain cost)", "secs": 25.0, "battle": false, "s": {"lights": 12, "rain": false}},
		{"name": "F. Heavy at 0.67: 24 chars (12 layered), 24 lights", "secs": 30.0, "battle": false, "s": {"chars": 24, "layered": 12, "lights": 24, "rain": true}},
		{"name": "G. Battle screen, auto-play, 0.67 scale", "secs": 25.0, "battle": true, "s": {"chars": 12, "layered": 4, "lights": 12, "fps_cap": 60}},
	]
	_begin_bench()


func start_soak() -> void:
	if bench_i >= 0:
		hud.show_toast("A test is already running.")
		return
	soak = true
	soak_rows.clear()
	soak_min_t = 0.0
	var cur := settings.duplicate()
	bench = [{"name": "Soak 60 min at scale %.2f, %d fps cap, %d lights" % [cur["scale"], cur["fps_cap"], cur["lights"]], "secs": 3600.0, "battle": false, "s": cur}]
	hud.settings_panel.visible = false
	_begin_bench()


func _begin_bench() -> void:
	bench_results.clear()
	bench_i = -1
	hud.test_btn.disabled = true
	_next_stage()


func stop_bench() -> void:
	if bench_i < 0:
		return
	metrics.stop_record()
	bench_i = bench.size()
	_finish_bench(true)


func _next_stage() -> void:
	bench_i += 1
	if bench_i >= bench.size():
		_finish_bench(false)
		return
	var st: Dictionary = bench[bench_i]
	if in_battle and not st["battle"]:
		set_battle(false)
	for k in st["s"].keys():
		settings[k] = st["s"][k]
	_apply_all()
	if st["battle"]:
		set_battle(true)
		battle.auto_play = true
		if battle.active()["team"] == "party" and not battle.busy:
			battle._ai_turn()
	bench_t = 0.0
	hud.show_toast("Test stage %d/%d: %s" % [bench_i + 1, bench.size(), st["name"]], 5.0)


func bench_status() -> String:
	if bench_i < 0 or bench_i >= bench.size():
		return ""
	var st: Dictionary = bench[bench_i]
	return "\nTEST %d/%d  %s  %ds left — keep the phone still, screen on" % [bench_i + 1, bench.size(), st["name"].substr(0, 40), int(st["secs"] - bench_t)]


func _process(delta: float) -> void:
	if bench_i < 0 or bench_i >= bench.size():
		return
	var st: Dictionary = bench[bench_i]
	var was := bench_t
	bench_t += delta
	if was < WARMUP and bench_t >= WARMUP:
		metrics.start_record()
	if soak and bench_t >= WARMUP:
		soak_min_t += delta
		if soak_min_t >= 60.0:
			soak_min_t = 0.0
			var r := metrics.stop_record()
			r["minute"] = soak_rows.size() + 1
			soak_rows.append(r)
			metrics.start_record()
	if bench_t >= st["secs"]:
		var r := metrics.stop_record()
		r["name"] = st["name"]
		bench_results.append(r)
		_next_stage()


func _finish_bench(stopped: bool) -> void:
	var save_r := do_save(true)
	var load_r := do_load(true)
	var saves := [save_r]
	for i in 2:
		saves.append(do_save(true))
	var lines: Array[String] = []
	lines.append("COLLAPSE RPG DEVICE TEST — %s%s" % [VERSION, "  (stopped early)" if stopped else ""])
	lines.append(metrics.device_line())
	lines.append("Date %s UTC. Battery at start %s, charging: %s" % [Time.get_datetime_string_from_system(true), str(metrics.battery_start_pct), str(metrics.sample.get("charging", "n/a"))])
	lines.append("")
	if soak:
		lines.append(String(bench[0]["name"]) if not bench.is_empty() else "")
		lines.append("SOAK, per minute: min | fps | p99 ms | slow>33 % | heat | headroom | battery % | RAM MB")
		for r in soak_rows:
			lines.append("%2d | %.1f | %.1f | %.1f | %s | %.2f | %d | %.0f" % [r["minute"], r["fps"], r["p99_ms"], r["slow33_pct"], Metrics.thermal_name(r["thermal"]), r["headroom"], r["batt_pct"], r["rss_mb"]])
		if soak_rows.size() >= 2:
			var first: Dictionary = soak_rows[0]
			var last: Dictionary = soak_rows[soak_rows.size() - 1]
			lines.append("Battery used: %.1f %% over %d min (%.1f %%/h). Worst heat: %s" % [
				first["batt_pct"] - last["batt_pct"], soak_rows.size(), (first["batt_pct"] - last["batt_pct"]) * 60.0 / soak_rows.size(), Metrics.thermal_name(metrics.max_thermal)])
	else:
		lines.append("stage | fps | avg ms | p99 ms | worst ms | slow>33ms % | >16.7ms % | draws | tex MB | RAM MB | heat | headroom | batt %/h")
		for r in bench_results:
			lines.append(r["name"])
			lines.append("   %.1f fps | %.1f | %.1f | %.1f | %.1f%% | %.1f%% | %.0f | %.0f | %.0f | %s | %.2f | %.1f" % [
				r["fps"], r["avg_ms"], r["p99_ms"], r["worst_ms"], r["slow33_pct"], r["over17_pct"], r["draws"], r["tex_mb"], r["rss_mb"],
				Metrics.thermal_name(r["thermal"]), r["headroom"], r["drain_pct_h"]])
	lines.append("")
	lines.append("Save: build %.1f ms, write %.1f ms, %.0f KB compressed (%.0f KB JSON, JSON write %.1f ms). Repeat writes %.1f / %.1f ms" % [
		save_r["build_ms"], save_r["bin_ms"], save_r["bin_kb"], save_r["json_kb"], save_r["json_ms"], saves[1]["bin_ms"], saves[2]["bin_ms"]])
	if not load_r.is_empty():
		lines.append("Load: read %.1f ms, apply %.1f ms, JSON parse %.1f ms, check %s" % [load_r["read_ms"], load_r["apply_ms"], load_r["json_parse_ms"], "OK" if load_r["ok"] else "FAILED"])
	if FileAccess.file_exists("user://autosave_note.txt"):
		lines.append("Last pause autosave: " + FileAccess.get_file_as_string("user://autosave_note.txt"))
	lines.append("Battery/heat probe: %s" % ("ok" if metrics.battery_mgr != null else metrics.android_error))
	lines.append("Budget (tech.md): 30 fps floor, 60 target, <25% frames over 33 ms, RAM <=1.5 GB, textures <=384 MB, <10%/h battery, no throttling in 60 min.")
	report = "\n".join(lines)
	var f := FileAccess.open("user://report_%s.txt" % ("soak" if soak else "quick"), FileAccess.WRITE)
	f.store_string(report)
	f.close()
	print(report)
	bench_i = -1
	hud.test_btn.disabled = false
	if in_battle:
		set_battle(false)
	settings = {"chars": 12, "layered": 4, "lights": 12, "rain": true, "night": true, "scale": 0.67, "fps_cap": 60}
	_apply_all()
	hud.show_report(report)
	if "--fast-bench" in OS.get_cmdline_user_args():
		await get_tree().create_timer(1.0).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("user://report_shot.png")
		get_tree().quit()
