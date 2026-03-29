#board creation setup

extends Node3D
@export var tile_scene : PackedScene
const TILE_WIDTH = 1.25
const CORNER_SIZE = 2.0

func _ready(): # calls create_board
	create_board()

func create_board(): #creates tiles
	for i in range(BoardData.TILES.size()):
		var tile_info = BoardData.TILES[i]
		var tile = tile_scene.instantiate()
		tile.tile_data = tile_info 
		tile.tile_type = tile_info["type"]
		
		var transform_data = calculate_tile_transform(i)
		tile.position = transform_data.position
		tile.rotation_degrees = transform_data.rotation
		$Tiles.add_child(tile)

func calculate_tile_transform(index): #helper function for position and rotation
	var side = index / 10
	var offset = index % 10
	
	var radius = 6.625 
	
	var pos = Vector3.ZERO
	var rot = Vector3.ZERO
	var edge_offset = 0.0
	
	if offset == 0:
		edge_offset = radius
	else:
		var start_pos = radius - (CORNER_SIZE / 2.0) - (TILE_WIDTH / 2.0)
		edge_offset = start_pos - ((offset - 1) * TILE_WIDTH)
		
	match side:
		0:
			pos = Vector3(edge_offset, 0, radius)
			rot.y = 0 
		1:
			pos = Vector3(-radius, 0, edge_offset)
			rot.y = -90
		2:
			pos = Vector3(-edge_offset, 0, -radius)
			rot.y = -180
		3:
			pos = Vector3(radius, 0, -edge_offset)
			rot.y = -270
	return {
		"position": pos,
		"rotation": rot
	}
	
