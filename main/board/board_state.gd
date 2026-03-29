extends Node3D
var tiles = []
@onready var game_controller = $"../../GameController"

func _ready(): #gets tiles node children
	await get_tree().process_frame # wait for board setup
	tiles = $"../Tiles".get_children()

func get_tiles(): # returns tiles array
	return tiles

#calculates rent for property with fund + investment, double rent for set rule, cafe and utilities
func calculate_rent(tile): #
	var data = tile.tile_data
	if tile.tile_type == BoardData.TileType.PROPERTY:
		var funding = tile.funding
		var rent_array = data.get("rent", [0])
		var base_rent = rent_array[funding]

		if funding == 0 and has_monopoly(tile.tile_owner, data.get("color", "")):
			return base_rent * 2
			
		return base_rent
	elif tile.tile_type == BoardData.TileType.CAFE:
		var tileOwner = tile.tile_owner
		var cafes = 0
		for t in get_tiles():
			if t.tile_type == BoardData.TileType.CAFE and t.tile_owner == tileOwner:
				cafes += 1
		return data["rent"][cafes-1]
	elif tile.tile_type == BoardData.TileType.UTILITY:
		var tileOwner = tile.tile_owner
		var utilities = 0
		for t in get_tiles():
			if t.tile_type == BoardData.TileType.UTILITY and t.tile_owner == tileOwner:
				utilities += 1
		var dice = game_controller.latest_die_sum
		if utilities == 1:
			return dice * 4
		else:
			return dice * 10
	return 0

#returns fund cost for each set
func get_investment_cost(tile):
	var color = tile.tile_data.get("color","")
	var rules = BoardData.property_rules.get(color)
	if rules == null:
		return 0
	return rules.investment

#check for monopoly
func has_monopoly(player, color: String) -> bool:
	if color == "" or player == null: return false
	var total_of_color = 0
	var player_owns_of_color = 0
	for t in get_tiles():
		if t.tile_type == BoardData.TileType.PROPERTY and t.tile_data.get("color") == color:
			total_of_color += 1
			if t.tile_owner == player:
				player_owns_of_color += 1
				
	return total_of_color > 0 and total_of_color == player_owns_of_color
