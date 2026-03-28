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

var is_monopoly := false # <--- ADD THIS LINE!
var tile_type : BoardData.TileType
var tile_data : Dictionary
var tile_owner = null
var funding := 0
var is_mortgaged := false

#tile initializatin
func _ready():
	original_y = position.y
	update_tile_shape()

# resizes tile shape and adds property strip, collision
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



#emits signal when clicked (tile_clicked)
func _on_area_3d_input_event(_camera, event, _position, _normal, _shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		tile_clicked.emit(self)

func _mouse_entered():
	set_highlight(true,Color.BISQUE)

func _mouse_exited():
	set_highlight(false)

func set_highlight(active: bool, glow_color := Color(1.0, 0.85, 0.5)):
	return
