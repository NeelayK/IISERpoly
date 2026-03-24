extends Control

@onready var main_panel = $UILayer/MainPanel
@onready var settings_panel = $UILayer/SettingsPanel
@onready var play_setup_panel = $UILayer/PlaySetupPanel
@onready var player_list = $UILayer/PlaySetupPanel/VBox/PlayerList

var player_row_scene = preload("res://main/main_menu/player_setup_row.tscn")
var pending_settings = {"mode": DisplayServer.WINDOW_MODE_WINDOWED, "res": Vector2i(1280, 720)}

func _ready():
	if GameConfig.is_training:
		_start_game()
	else:
		_show_panel(main_panel)
		main_panel.get_node("PlayBtn").pressed.connect(func(): _show_panel(play_setup_panel))
		main_panel.get_node("SettingsBtn").pressed.connect(func(): _show_panel(settings_panel))
		main_panel.get_node("QuitBtn").pressed.connect(func(): get_tree().quit())
		
		var apply_btn = settings_panel.get_node("VBox/HBox/ApplyBtn")
		var settings_back_btn = settings_panel.get_node("VBox/HBox/BackBtn")
		apply_btn.pressed.connect(_apply_settings)
		settings_back_btn.pressed.connect(func(): _show_panel(main_panel))
		
		_setup_settings_options()
		
		var add_player_btn = play_setup_panel.get_node("VBox/HBox1/AddPlayerBtn")
		var rem_player_btn = play_setup_panel.get_node("VBox/HBox1/RemPlayerBtn")
		var start_btn = play_setup_panel.get_node("VBox/HBox/StartGameBtn")
		var setup_back_btn = play_setup_panel.get_node("VBox/HBox/BackBtn")
		
		add_player_btn.pressed.connect(_add_player_row)
		rem_player_btn.pressed.connect(_rem_player_row)
		start_btn.pressed.connect(_start_game)
		setup_back_btn.pressed.connect(func(): _show_panel(main_panel))
		
		_add_player_row()
		_add_player_row()

func _process(delta):
	for row in player_list.get_children():
		var mesh_instance = row.get_node_or_null("FigurineView/SubViewport/FigurineMesh")
		if mesh_instance:
			mesh_instance.rotate_y(1.0 * delta)

func _show_panel(panel_to_show: Control):
	main_panel.hide()
	settings_panel.hide()
	play_setup_panel.hide()
	panel_to_show.show()

func _setup_settings_options():
	var mode_btn = settings_panel.get_node("VBox/Display/DisplayModeButton")
	var res_btn = settings_panel.get_node("VBox/Resolution/Resolution")
	
	mode_btn.add_item("Windowed", DisplayServer.WINDOW_MODE_WINDOWED)
	mode_btn.add_item("Fullscreen", DisplayServer.WINDOW_MODE_FULLSCREEN)
	mode_btn.add_item("Borderless", DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	
	var current_mode = DisplayServer.window_get_mode()
	var mode_idx = mode_btn.get_item_index(current_mode)
	if mode_idx != -1:
		mode_btn.select(mode_idx)
		pending_settings.mode = current_mode
		
	res_btn.disabled = (current_mode != DisplayServer.WINDOW_MODE_WINDOWED)

	mode_btn.item_selected.connect(func(idx): 
		pending_settings.mode = mode_btn.get_item_id(idx)
		res_btn.disabled = (pending_settings.mode != DisplayServer.WINDOW_MODE_WINDOWED)
	)
	
	res_btn.add_item("1920x1080", 0)
	res_btn.set_item_metadata(0, Vector2i(1920, 1080))
	res_btn.add_item("1280x720", 1)
	res_btn.set_item_metadata(1, Vector2i(1280, 720))
	res_btn.add_item("1152x648", 2)
	res_btn.set_item_metadata(2, Vector2i(1152, 648))
	
	var current_res = DisplayServer.window_get_size()
	pending_settings.res = current_res
	for i in range(res_btn.item_count):
		if res_btn.get_item_metadata(i) == current_res:
			res_btn.select(i)
			break

	res_btn.item_selected.connect(func(idx): 
		pending_settings.res = res_btn.get_item_metadata(idx)
	)

func _apply_settings():
	DisplayServer.window_set_mode(pending_settings.mode)
	if pending_settings.mode == DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_size(pending_settings.res)
		var current_screen = DisplayServer.window_get_current_screen()
		var screen_size = DisplayServer.screen_get_size(current_screen)
		var window_position = (screen_size / 2) - (pending_settings.res / 2)
		DisplayServer.window_set_position(window_position)

	var base_height = 720.0
	var current_height = pending_settings.res.y
	var new_scale = current_height / base_height
	GameConfig.new_scale =  new_scale
	get_tree().root.content_scale_factor = new_scale
	print("Settings Applied and UI Rescaled to: ", new_scale)

func _add_player_row():
	var current_count = player_list.get_child_count()
	if current_count >= 6: return 
	
	var row = player_row_scene.instantiate()
	player_list.add_child(row)
	
	var viewport = row.get_node("FigurineView/SubViewport")
	viewport.own_world_3d = true 
	
	var mesh_instance = viewport.get_node("FigurineMesh")
	var type_select = row.get_node("TypeSelect")
	var color_select = row.get_node("ColorSelect")
	var shiny_select = row.get_node("ShinySelect")
	var ai_select = row.get_node("AISelect")
	
	ai_select.clear()
	ai_select.add_item("Human")
	ai_select.add_item("AI")
		
	shiny_select.clear()
	shiny_select.add_item("Matte")
	shiny_select.add_item("Satin")
	shiny_select.add_item("Glossy")
		
	
	type_select.clear()
	for fig in GameConfig.FIGURINE_MESHES:
		type_select.add_item(fig["name"])
	
	color_select.clear()
	for color_name in GameConfig.ALLOWED_COLORS.keys():
		color_select.add_item(color_name)

	type_select.selected = current_count % GameConfig.FIGURINE_MESHES.size()
	color_select.selected = current_count % GameConfig.ALLOWED_COLORS.size()
	shiny_select.selected = 0
	ai_select.selected = 0 
	
	mesh_instance.mesh = GameConfig.FIGURINE_MESHES[type_select.selected]["model"]


	var mat = StandardMaterial3D.new()
	mesh_instance.material_override = mat
	
	var update_preview_mat = func():
		var color_idx = color_select.selected
		if color_idx != -1:
			var color_name = color_select.get_item_text(color_idx)
			if GameConfig.ALLOWED_COLORS.has(color_name):
				mat.albedo_color = GameConfig.ALLOWED_COLORS[color_name]
		
		if shiny_select.selected == 1:
			mat.metallic = 1.0
			mat.roughness = 0.7
		elif shiny_select.selected == 2:
			mat.metallic = 0.0
			mat.roughness = 0.2
		else:
			mat.metallic = 0.0
			mat.roughness = 0.8

	# --- 4. CONNECT SIGNALS ---
	color_select.item_selected.connect(func(_idx): update_preview_mat.call())
	shiny_select.item_selected.connect(func(_idx): update_preview_mat.call())
	
	type_select.item_selected.connect(func(idx):
		mesh_instance.mesh = GameConfig.FIGURINE_MESHES[idx]["model"]
	)

	update_preview_mat.call()

#switch scenes nd initiizalize entireis to player data
func _start_game():
	GameConfig.player_data.clear()
	for row in player_list.get_children():
		var p_name = row.get_node("NameInput").text
		if p_name == "": p_name = "Player " + str(row.get_index() + 1)
		GameConfig.player_data.append({
			"name": p_name,
			"color": GameConfig.ALLOWED_COLORS[row.get_node("ColorSelect").get_item_text(row.get_node("ColorSelect").selected)],
			"model": GameConfig.FIGURINE_MESHES[row.get_node("TypeSelect").selected]["model"],
			"is_ai": row.get_node("AISelect").selected > 0,
			"is_metal": row.get_node("ShinySelect").selected == 1
		})
	get_tree().change_scene_to_file("res://main/board_items/game.tscn")
	
#remove last player row
func _rem_player_row():
	var rows = player_list.get_children()
	if rows.size() > 2:
		var last_row = rows[-1]
		player_list.remove_child(last_row)
		last_row.queue_free()
