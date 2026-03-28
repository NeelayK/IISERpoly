extends Node
class_name PropertyManager

var board_state: Node

#setup called in GC
func setup(state_node: Node):
	board_state = state_node

#updating tile state (build,sell,mortgage,unmortgage)
func execute_action(tile, mode: String, player):
	match mode:
		"build":
			var cost = board_state.get_investment_cost(tile)
			player.money -= cost
			tile.funding += 1
		"sell":
			var cost = board_state.get_investment_cost(tile) / 2
			player.money += cost
			tile.funding -= 1
		"mortgage":
			var amount = tile.tile_data.get("price", 0) / 2
			player.money += amount
			tile.is_mortgaged = true
		"unmortgage":
			var cost = int((tile.tile_data.get("price", 0) / 2) * 1.1)
			player.money -= cost
			tile.is_mortgaged = false
			

#check validity for property functions (highlights in gc)
func is_valid_for_action(tile, mode: String, player, all_tiles: Array) -> bool:
	if tile.tile_type != BoardData.TileType.PROPERTY: return false
	
	var color_set = []
	for t in all_tiles:
		if t.tile_type == BoardData.TileType.PROPERTY and t.tile_data.get("color") == tile.tile_data.get("color"):
			color_set.append(t)

	match mode:
		"build":
			if not board_state.has_monopoly(player, tile.tile_data.color): return false
			if tile.funding >= 5 or tile.is_mortgaged: return false
			if player.money < board_state.get_investment_cost(tile): return false
			for other in color_set:
				if other.funding < tile.funding or other.is_mortgaged: return false
			return true
		"sell":
			if tile.funding <= 0: return false
			for other in color_set:
				if other.funding > tile.funding: return false
			return true
		"mortgage":
			for other in color_set:
				if other.funding > 0: return false
			return not tile.is_mortgaged
		"unmortgage":
			var cost = int((tile.tile_data.get("price", 0) / 2) * 1.1)
			return tile.is_mortgaged and player.money >= cost
			
	return false
