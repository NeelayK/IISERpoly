extends Node3D

signal tile_clicked(tile)

const DEFAULT_MATERIAL = preload("res://materials/Tile/Tile.tres")
const INK_COLOR = Color("#2e2a28")
const FONT_SIZE_MULTIPLIER = 1.5
const LABEL_HEIGHT := 0.105
const TILE_SIZE := Vector3(1.25, 0.2, 2.0)
const CORNER_SIZE := Vector3(2.0, 0.2, 2.0)
var original_y: float = 0.0
var highlight_tween: Tween

@onready var base := $Base
@onready var property_strip := $PropertyStrip
@onready var selection_shape := $Selection/Shape
@onready var collision_shape := $Collision/Shape
@onready var building_container := $BuildingContainer
@export var coin_model : PackedScene 
@export var gold_bar : PackedScene 
@export var cross : PackedScene 

var tile_type : BoardData.TileType
var tile_data : Dictionary
var funding := 0
var is_mortgaged := false
# Add at top with other variables
var _persistent_highlight := false
var _persistent_glow_color := Color(1.0, 0.85, 0.5)

var tile_owner = null:
	set(value):
		tile_owner = value
		if is_inside_tree():
			refresh_owner_marker()

func refresh_owner_marker():
	for child in get_children():
		if child.is_in_group("owner_marker"):
			child.queue_free()

	if tile_owner == null: return
	if tile_type not in [BoardData.TileType.PROPERTY, BoardData.TileType.CAFE, BoardData.TileType.UTILITY]:
		return
	var mesh_node = tile_owner.get_node_or_null("MeshInstance3D")
	var mi := MeshInstance3D.new()
	mi.mesh = mesh_node.mesh
	mi.scale = Vector3(0.15,0.15,0.15)
	mi.material_override = mesh_node.material_override 

	add_child(mi)
	mi.add_to_group("owner_marker")
	mi.position = Vector3(-0.25, LABEL_HEIGHT, -0.72)


func set_highlight(active: bool, glow_color := Color(1.0, 0.85, 0.5), persistent: bool = false):
	if persistent:
		_persistent_highlight = active
		_persistent_glow_color = glow_color
	elif not active:
		_persistent_highlight = false

	if highlight_tween and highlight_tween.is_running():
		highlight_tween.kill()
	highlight_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	var target_y = original_y + (0.05 if active else 0.0)
	highlight_tween.tween_property(self, "position:y", target_y, 0.3)

	var mat = base.material_override as StandardMaterial3D
	if mat:
		mat.emission_enabled = true
		mat.emission = glow_color
		var target_energy = 0.35 if active else 0.0
		highlight_tween.tween_property(mat, "emission_energy_multiplier", target_energy, 0.3)

	var players_nearby = get_tree().get_nodes_in_group("players")
	for p in players_nearby:
		var dist = Vector2(p.global_position.x, p.global_position.z) \
					.distance_to(Vector2(global_position.x, global_position.z))
		if dist < 0.8:
			var parent_y = get_parent().global_position.y if get_parent() else 0.0
			highlight_tween.tween_property(p, "global_position:y", parent_y, 0.3)

func _mouse_entered():
	if not _persistent_highlight:
		set_highlight(true, Color.BISQUE)

func _mouse_exited():
	if _persistent_highlight:
		set_highlight(true, _persistent_glow_color)
	else:
		set_highlight(false)

func _ready():
	original_y = position.y
	update_tile_shape()
	create_tile_labels()

func update_tile_shape():
	var is_corner = (tile_type == BoardData.TileType.CORNER)
	var target_size = CORNER_SIZE if is_corner else TILE_SIZE

	if base.mesh == null: base.mesh = BoxMesh.new()
	base.mesh.size = target_size
	
	if collision_shape.shape == null: collision_shape.shape = BoxShape3D.new()
	collision_shape.shape.size = Vector3(target_size.x, 0.2, target_size.z)/1.01
	collision_shape.position.y = 0
	
	if selection_shape.shape == null: selection_shape.shape = BoxShape3D.new()
	selection_shape.shape.size = target_size

	var mat = DEFAULT_MATERIAL.duplicate() as StandardMaterial3D
	mat.albedo_color = BoardData.COLOR_DEFAULT
	base.material_override = mat

	if tile_type == BoardData.TileType.PROPERTY:
		property_strip.visible = true
		if property_strip.mesh == null: property_strip.mesh = BoxMesh.new()
		property_strip.mesh.size = Vector3(1.25, 0.001, 0.5)
		property_strip.position = Vector3(0, 0.101, -0.75)
		
		var strip_mat = StandardMaterial3D.new()
		var color_key = tile_data.get("color", "")
		strip_mat.albedo_color = BoardData.PROPERTY_COLORS.get(color_key, BoardData.COLOR_DEFAULT)
		property_strip.material_override = strip_mat
	else:
		property_strip.visible = false

# creates labels, text for each tile.
func create_tile_labels():
	var tile_name = tile_data.get("name", "Unknown")
	var price_text = "$" + str(tile_data.get("price", 0))
	var icon_path = tile_data.get("icon", BoardData.ICON_DEFAULT)

	match tile_type:
		BoardData.TileType.PROPERTY:
			create_text_label(tile_name, Vector3(0, LABEL_HEIGHT, -0.2), 0.5, 0, 250.0)
			create_text_label(price_text, Vector3(0, LABEL_HEIGHT, 0.8), 0.7, 0)
		BoardData.TileType.CHANCE, BoardData.TileType.PROJECT_FUNDS:
			create_text_label(tile_name, Vector3(0, LABEL_HEIGHT, -0.6), 0.55, 0, 400.0)
			create_icon(icon_path, Vector3(0, LABEL_HEIGHT, 0.2))
		BoardData.TileType.CAFE, BoardData.TileType.UTILITY, BoardData.TileType.FEES:
			create_text_label(tile_name, Vector3(0, LABEL_HEIGHT, -0.6), 0.5, 0, 400.0)
			create_icon(icon_path, Vector3(0, LABEL_HEIGHT, 0.1))
			create_text_label(price_text, Vector3(0, LABEL_HEIGHT, 0.8), 0.6, 0)
		BoardData.TileType.CORNER:
			create_text_label(tile_name, Vector3(-0.4, LABEL_HEIGHT, -0.4), 0.8, 45, 500.0)
			create_icon(icon_path, Vector3(0.1, LABEL_HEIGHT, 0.1), 45)

#helpers
func create_text_label(text:String, pos:Vector3, scale_val:float, rot:int = 0, wrap_width:float = 300.0):
	var label = Label3D.new()
	label.text = text
	label.position = pos
	label.rotation_degrees = Vector3(-90, 0, rot)
	var final_scale = scale_val * FONT_SIZE_MULTIPLIER
	label.scale = Vector3(final_scale, final_scale, final_scale)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.width = wrap_width
	label.modulate = INK_COLOR
	label.outline_modulate = Color(0,0,0,0)
	add_child(label)
func create_icon(path:String, pos:Vector3, rot:int = 0):
	var sprite = Sprite3D.new()
	sprite.texture = load(path) if ResourceLoader.exists(path) else load(BoardData.ICON_DEFAULT)
	sprite.position = pos
	sprite.rotation_degrees = Vector3(-90, 0, rot)
	sprite.pixel_size = 0.0015
	sprite.modulate = INK_COLOR
	add_child(sprite)

func refresh_buildings():
	for child in building_container.get_children():
		child.queue_free()

	if tile_type != BoardData.TileType.PROPERTY:
		return
	if is_mortgaged:
		if cross:
			var c = cross.instantiate()
			building_container.add_child(c)
			c.global_position = property_strip.global_position + Vector3(0, 0.3, 0)
		return

	if funding >= 5:
		if gold_bar:
			var bar_offsets = [
				Vector3(0.0, 0.12, 0.0),
				Vector3( 0.1, 0.12, 0.0),
				Vector3( 0.2,  0.28, 0.0),
			]
			for offset in bar_offsets:
				var bar = gold_bar.instantiate()
				building_container.add_child(bar)
				if bar is RigidBody3D:
					bar.linear_velocity  = Vector3.ZERO
					bar.angular_velocity = Vector3(0.2,0.4,0.2)
				bar.global_position = property_strip.global_position + offset
		return

	# Levels 1–4: coins
	for i in range(funding):
		spawn_coin(i)


func spawn_coin(index: int):
	var coin = coin_model.instantiate()
	building_container.add_child(coin)
	if coin is RigidBody3D:
		coin.linear_velocity  = Vector3.ZERO
		coin.angular_velocity = Vector3.ZERO
	var spawn_y     = 0.4 + (index * 0.18)
	var rand_offset = Vector3(randf_range(-0.08, 0.08), 0.0, randf_range(-0.08, 0.08))
	coin.global_position = property_strip.global_position + Vector3(0.25, spawn_y, 0) + rand_offset
	coin.scale = Vector3(0.8, 0.8, 0.8)

#emits signal when clicked (tile_clicked)
func _on_area_3d_input_event(_camera, event, _position, _normal, _shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		tile_clicked.emit(self)
