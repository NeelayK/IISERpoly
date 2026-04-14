extends Node

@onready var main_panel       = $UILayer/MainPanel
@onready var settings_panel   = $UILayer/SettingsPanel
@onready var play_setup_panel = $UILayer/PlaySetupPanel
@onready var player_list      = $UILayer/PlaySetupPanel/VBox/PlayerList
@onready var camera           = $Camera3D
@onready var music_player     = $MenuMusic
@onready var volume_bar       = $UILayer/SettingsPanel/VBox/Volume/MasterVolume
@onready var sfx_player       = $SFXPlayer

const CLICK_SOUNDS: Array[String] = [
	"res://assets/sounds/Boom2.wav",
	"res://assets/sounds/Boom1.wav"
]

var ui_base_offset: Vector2 = Vector2.ZERO
var player_row_scene = preload("res://main/main_menu/player_setup_row.tscn")
var pending_settings  = {"mode": DisplayServer.WINDOW_MODE_WINDOWED, "res": Vector2i(1280, 720)}
var current_panel: Control
var shake_strength: float = 0.0
var _all_panels: Array[Control]


func _ready():
	_all_panels = [main_panel, settings_panel, play_setup_panel]

	# Hide everything first so layout runs with correct visibility
	for p in _all_panels:
		p.hide()
		p.modulate.a = 0.0

	# Wait for TWO frames so Godot finishes layout and .size is valid
	await get_tree().process_frame
	await get_tree().process_frame

	# Center every panel and set pivot to its true centre
	for p in _all_panels:
		p.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		p.pivot_offset = p.size / 2.0

	# Initial state
	main_panel.scale = Vector2(0.8, 0.8)
	current_panel    = main_panel
	main_panel.show()
	ui_base_offset = $UILayer.offset
	_animate_menu_entrance()
	_setup_button_juice()
	_wire_buttons()
	_setup_settings_options()
	_add_player_row()
	_add_player_row()

	var d = Time.get_date_dict_from_system()
	$UILayer/MainPanel/Time.text = "Credits: 0%02d" % [d.day]

	$UILayer/MainPanel/SettingsBtn.visible = not OS.has_feature("mobile")

	if not music_player.playing:
		music_player.play()
	_initialize_volume_settings()
	volume_bar.value_changed.connect(_on_volume_changed)


func _wire_buttons():
	main_panel.get_node("PlayBtn").pressed.connect(func(): _show_panel(play_setup_panel))
	main_panel.get_node("SettingsBtn").pressed.connect(func(): _show_panel(settings_panel))
	main_panel.get_node("QuitBtn").pressed.connect(get_tree().quit)

	settings_panel.get_node("VBox/HBox/ApplyBtn").pressed.connect(_apply_settings)
	settings_panel.get_node("VBox/HBox/BackBtn").pressed.connect(func(): _show_panel(main_panel))

	play_setup_panel.get_node("VBox/HBox1/AddPlayerBtn").pressed.connect(_add_player_row)
	play_setup_panel.get_node("VBox/HBox1/RemPlayerBtn").pressed.connect(_rem_player_row)
	play_setup_panel.get_node("VBox/HBox/StartGameBtn").pressed.connect(_start_game)
	play_setup_panel.get_node("VBox/HBox/BackBtn").pressed.connect(func(): _show_panel(main_panel))


func _process(delta):
	camera.rotate_z(deg_to_rad(3.0) * delta)

	for row in player_list.get_children():
		var mesh = row.get_node_or_null("FigurineView/SubViewport/FigurineMesh")
		if mesh:
			mesh.rotate_y(1.0 * delta)

	if shake_strength > 0.01:
		shake_strength = lerpf(shake_strength, 0.0, 5.0 * delta)

		camera.h_offset = randf_range(-shake_strength, shake_strength) * 0.1
		camera.v_offset = randf_range(-shake_strength, shake_strength) * 0.1

		$UILayer.offset = ui_base_offset + Vector2(
			randf_range(-shake_strength, shake_strength),
			randf_range(-shake_strength, shake_strength)
		) * 20.0

	elif shake_strength > 0.0:
		shake_strength  = 0.0
		camera.h_offset = 0.0
		camera.v_offset = 0.0
		$UILayer.offset = ui_base_offset


# ── Panel transitions ────────────────────────────────────────────────────────

func _show_panel(next: Control):
	if current_panel == next:
		return

	# Re-center in case the window was resized since startup
	next.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	next.pivot_offset = next.size / 2.0

	var tween = create_tween().set_parallel(true)

	if current_panel:
		var prev = current_panel
		tween.tween_property(prev, "modulate:a", 0.0, 0.2).set_trans(Tween.TRANS_SINE)
		tween.tween_callback(prev.hide).set_delay(0.2)

	next.modulate.a = 0.0
	next.show()
	tween.tween_property(next, "modulate:a", 1.0, 0.3) \
		.set_trans(Tween.TRANS_SINE).set_delay(0.1)

	current_panel = next


# ── Settings ─────────────────────────────────────────────────────────────────

func _setup_settings_options():
	var mode_btn = settings_panel.get_node("VBox/Display/DisplayModeButton")
	var res_btn  = settings_panel.get_node("VBox/Resolution/Resolution")

	mode_btn.add_item("Windowed",   DisplayServer.WINDOW_MODE_WINDOWED)
	mode_btn.add_item("Fullscreen", DisplayServer.WINDOW_MODE_FULLSCREEN)
	mode_btn.add_item("Borderless", DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)

	var current_mode = DisplayServer.window_get_mode()
	var mode_idx     = mode_btn.get_item_index(current_mode)
	if mode_idx != -1:
		mode_btn.select(mode_idx)
		pending_settings.mode = current_mode

	res_btn.disabled = (current_mode != DisplayServer.WINDOW_MODE_WINDOWED)
	mode_btn.item_selected.connect(func(idx):
		pending_settings.mode = mode_btn.get_item_id(idx)
		res_btn.disabled = (pending_settings.mode != DisplayServer.WINDOW_MODE_WINDOWED)
	)

	var resolutions = [
		{"label": "1920x1080", "res": Vector2i(1920, 1080)},
		{"label": "1280x720",  "res": Vector2i(1280, 720)},
		{"label": "1152x648",  "res": Vector2i(1152, 648)},
	]
	var current_res = DisplayServer.window_get_size()
	pending_settings.res = current_res

	for i in resolutions.size():
		res_btn.add_item(resolutions[i]["label"], i)
		res_btn.set_item_metadata(i, resolutions[i]["res"])
		if resolutions[i]["res"] == current_res:
			res_btn.select(i)

	res_btn.item_selected.connect(func(idx):
		pending_settings.res = res_btn.get_item_metadata(idx)
	)


func _apply_settings():
	DisplayServer.window_set_mode(pending_settings.mode)
	if pending_settings.mode == DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_size(pending_settings.res)
		var screen      = DisplayServer.window_get_current_screen()
		var screen_size = DisplayServer.screen_get_size(screen)
		DisplayServer.window_set_position(
			Vector2i((screen_size - pending_settings.res) / 2)
		)

	var scale = float(pending_settings.res.y) / 720.0
	GameConfig.new_scale = scale
	get_tree().root.content_scale_factor = scale
	print("Settings applied — UI scale: ", scale)


# ── Player rows ───────────────────────────────────────────────────────────────

func _add_player_row():
	if player_list.get_child_count() >= 6:
		return

	var row           = player_row_scene.instantiate()
	player_list.add_child(row)
	var idx           = row.get_index()

	var viewport      = row.get_node("FigurineView/SubViewport")
	viewport.own_world_3d = true

	var mesh_instance = viewport.get_node("FigurineMesh")
	var type_select   = row.get_node("TypeSelect")
	var color_select  = row.get_node("ColorSelect")
	var shiny_select  = row.get_node("ShinySelect")
	var ai_select     = row.get_node("AISelect")

	ai_select.clear()
	for label in ["Human", "AI-PPO", "AI-Heuristic"]:
		ai_select.add_item(label)

	shiny_select.clear()
	for label in ["Matte", "Satin", "Glossy"]:
		shiny_select.add_item(label)

	type_select.clear()
	for fig in GameConfig.FIGURINE_MESHES:
		type_select.add_item(fig["name"])

	color_select.clear()
	for color_name in GameConfig.ALLOWED_COLORS.keys():
		color_select.add_item(color_name)

	type_select.selected  = idx % GameConfig.FIGURINE_MESHES.size()
	color_select.selected = idx % GameConfig.ALLOWED_COLORS.size()
	shiny_select.selected = 0
	ai_select.selected    = 1

	mesh_instance.mesh = GameConfig.FIGURINE_MESHES[type_select.selected]["model"]

	var mat = StandardMaterial3D.new()
	mesh_instance.material_override = mat

	# Shared material update — called on any control change
	var update_mat = func():
		var name = color_select.get_item_text(color_select.selected)
		mat.albedo_color = GameConfig.ALLOWED_COLORS.get(name, Color.WHITE)
		match shiny_select.selected:
			1: mat.metallic = 1.0; mat.roughness = 0.7   # Satin
			2: mat.metallic = 0.0; mat.roughness = 0.2   # Glossy
			_: mat.metallic = 0.0; mat.roughness = 0.8   # Matte

	color_select.item_selected.connect(func(_i): update_mat.call())
	shiny_select.item_selected.connect(func(_i): update_mat.call())
	type_select.item_selected.connect(func(i):
		mesh_instance.mesh = GameConfig.FIGURINE_MESHES[i]["model"]
	)

	update_mat.call()


func _rem_player_row():
	var rows = player_list.get_children()
	if rows.size() > 2:
		rows[-1].queue_free()


func _start_game():
	GameConfig.player_data.clear()

	for row in player_list.get_children():
		var p_name = row.get_node("NameInput").text.strip_edges()
		if p_name.is_empty():
			p_name = "Player %d" % (row.get_index() + 1)

		var ai_idx = row.get_node("AISelect").selected
		GameConfig.player_data.append({
			"name":     p_name,
			"color":    GameConfig.ALLOWED_COLORS[row.get_node("ColorSelect").get_item_text(row.get_node("ColorSelect").selected)],
			"model":    GameConfig.FIGURINE_MESHES[row.get_node("TypeSelect").selected]["model"],
			"is_ai":    ai_idx > 0,
			"is_ppo":   ai_idx == 1,
			"is_metal": row.get_node("ShinySelect").selected == 1,
		})

	call_deferred("_go_to_game_scene")


func _go_to_game_scene():
	get_tree().change_scene_to_file("res://main/main_menu/loading.tscn")


# ── Audio ─────────────────────────────────────────────────────────────────────

func _initialize_volume_settings():
	var bus = AudioServer.get_bus_index("Master")
	volume_bar.min_value = 0.0
	volume_bar.max_value = 1.0
	volume_bar.step      = 0.01
	volume_bar.value     = db_to_linear(AudioServer.get_bus_volume_db(bus))


func _on_volume_changed(value: float):
	var bus = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus, linear_to_db(value))
	AudioServer.set_bus_mute(bus, value <= 0.0)


# ── Button juice ─────────────────────────────────────────────────────────────

func _animate_menu_entrance():
	var tween = create_tween().set_parallel(true) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(main_panel, "modulate:a", 1.0, 1.0)
	tween.tween_property(main_panel, "scale",      Vector2.ONE, 0.8)


func _setup_button_juice():
	for btn in get_tree().get_nodes_in_group("JuicyButtons"):
		if btn is Button:
			btn.pivot_offset = btn.size / 2.0
			btn.pressed.connect(_on_juicy_button_pressed.bind(btn))


func _on_juicy_button_pressed(btn: Button):
	sfx_player.stream = load(CLICK_SOUNDS.pick_random())
	sfx_player.play()

	var t = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(btn, "scale", Vector2(0.8, 0.), 0.05)
	t.tween_property(btn, "scale", Vector2.ONE, 0.2)

	if btn.is_in_group("Explode"):
		_trigger_explosion()


# ── Explosion / shake ────────────────────────────────────────────────────────

func _trigger_explosion():
	shake_strength = 1.0

	var flash = ColorRect.new()
	flash.color        = Color(1, 1, 1, 0.8)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	$UILayer.add_child(flash)

	var ft = create_tween()
	ft.tween_property(flash, "modulate:a", 0.0, 0.25)
	ft.tween_callback(flash.queue_free)
