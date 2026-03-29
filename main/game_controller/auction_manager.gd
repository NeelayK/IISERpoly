extends Node
class_name AuctionManager

signal auction_finished(winner, property, final_price)

var ui: CanvasLayer
var auction_property = null
var gc: Node3D
var participants = []
var current_bid = 0
var highest_bidder = null
var turn_index = 0

func setup(main_ui: CanvasLayer,game_controller: Node3D): 
	ui = main_ui
	gc = game_controller

func start_auction(property, all_players: Array): 
	auction_property = property
	participants = all_players.duplicate()
	current_bid = 0
	highest_bidder = null
	turn_index = 0
	_process_turn()

func _process_turn(): 
	if participants.size() == 1 and highest_bidder != null:
		_end_auction(participants[0])
		return
		
	if participants.size() < 1:
		_end_auction(null)
		return

	if turn_index >= participants.size():
		turn_index = 0

	var bidding_player = participants[turn_index]
	
	var minimum_bid = current_bid + 10

	if bidding_player.money < minimum_bid:
		if bidding_player.is_ai:
			print("[AI - " + bidding_player.player_name + "] Cannot afford minimum bid of $" + str(minimum_bid) + ". Folding.")
		fold_auction()
		return    
		
	# --- AI_BLOCK ---
	if bidding_player.is_ai:
		if ui.has_method("hide_auction_panel"):
			ui.hide_auction_panel()
		_handle_ai_auction(bidding_player, minimum_bid)
	# ----------------------------
	else:
		ui.show_auction_panel(bidding_player, auction_property, current_bid, highest_bidder, place_bid, fold_auction)

func _handle_ai_auction(ai_player, minimum_bid):
	var prop_name  = auction_property.tile_data.get("name", "Unknown Property")
	var prop_value = auction_property.tile_data.get("price", 0)

	print("\n--- Auction: " + ai_player.player_name + "'s Turn ---")
	print("[AI] Property: " + prop_name + " | Base Value: $" + str(prop_value))
	print("[AI] Current Bid: $" + str(current_bid) + " | My Money: $" + str(ai_player.money))
	await get_tree().create_timer(0.1).timeout
	var perceived_value = prop_value

	var color = auction_property.tile_data.get("color", "")
	if color != "" and auction_property.tile_type == BoardData.TileType.PROPERTY:
		var set_size := 0
		var ai_has   := 0
		for t in gc.tiles:
			if t.tile_type == BoardData.TileType.PROPERTY and t.tile_data.get("color", "") == color:
				set_size += 1
				if t.tile_owner == ai_player: ai_has += 1
		if ai_has == set_size - 1:
			perceived_value = int(prop_value * 1.5)
		elif ai_has > 0:
			perceived_value = int(prop_value * 1.2)
	var reserve      = 150 + ai_player.properties.size() * 15
	var surplus      = ai_player.money - reserve
	var max_willing  : int

	if surplus <= 0:
		max_willing = int(perceived_value * 0.5)
	elif surplus < prop_value * 0.5:
		max_willing = int(perceived_value * 0.65)
	elif surplus < prop_value:
		max_willing = int(perceived_value * 0.9)
	else:
		max_willing = int(perceived_value * 1.15)

	max_willing = min(max_willing, int(ai_player.money * 0.6))

	print("[AI] Perceived value: $" + str(perceived_value) +
		  " | Willing to pay up to: $" + str(max_willing))

	if minimum_bid > max_willing or minimum_bid > ai_player.money:
		var reason = "Bid exceeds what I'm willing to pay." if minimum_bid > max_willing \
				else "Not enough money."
		print("[AI] Decision: Folding. (" + reason + ")")
		fold_auction()
	else:
		print("[AI] Decision: Bidding $" + str(minimum_bid))
		place_bid(minimum_bid)

func place_bid(amount: int): 
	var bidding_player = participants[turn_index]
	if amount <= current_bid or amount > bidding_player.money: return

	current_bid = amount
	highest_bidder = bidding_player
	turn_index += 1
	_process_turn()

func fold_auction(): 
	participants.remove_at(turn_index)
	if turn_index >= participants.size():
		turn_index = 0
	_process_turn()

func _end_auction(winner): 
	if ui.has_method("hide_auction_panel"):
		ui.hide_auction_panel()
	auction_finished.emit(winner, auction_property, current_bid)
