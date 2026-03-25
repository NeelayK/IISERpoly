extends Node
class_name AuctionManager

signal auction_finished(winner, property, final_price)

var ui: CanvasLayer
var auction_property = null
var participants = []
var current_bid = 0
var highest_bidder = null
var turn_index = 0

func setup(main_ui: CanvasLayer): 
	ui = main_ui

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

# --- AI_BLOCK ---
func _handle_ai_auction(ai_player, minimum_bid):
	var prop_name = auction_property.tile_data.get("name", "Unknown Property")
	var prop_value = auction_property.tile_data.get("price", 0)
	
	print("\n--- Auction: " + ai_player.player_name + "'s Turn ---")
	print("[AI] Property: " + prop_name + " | Base Value: $" + str(prop_value))
	print("[AI] Current Bid: $" + str(current_bid) + " | My Money: $" + str(ai_player.money))
	print("[AI] Options: Bid $" + str(minimum_bid) + ", Fold")
 
	await get_tree().create_timer(1.0).timeout
	
	if minimum_bid <= prop_value and minimum_bid <= ai_player.money:
		print("[AI] Decision: Bidding $" + str(minimum_bid))
		place_bid(minimum_bid)
	else:
		var reason = "Too expensive." if minimum_bid > prop_value else "Not enough money."
		print("[AI] Decision: Folding. (" + reason + ")")
		fold_auction()
# ----------------------------

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
