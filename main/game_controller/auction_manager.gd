extends Node
class_name AuctionManager

signal auction_finished(winner, property, final_price)

var ui: CanvasLayer
var auction_property = null
var participants = []
var current_bid = 0
var gc
var highest_bidder = null
var turn_index = 0

func setup(game_controller, main_ui: CanvasLayer): 
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
	var _minimum_bid = current_bid + 10
	ui.show_auction_panel(
		bidding_player, 
		auction_property, 
		current_bid, 
		highest_bidder, 
		place_bid, 
		fold_auction
	)

func place_bid(amount: int): 
	if participants.is_empty(): return
	if turn_index >= participants.size(): turn_index = 0
	
	var bidding_player = participants[turn_index]
	
	if amount <= current_bid or amount > bidding_player.money: return

	if bidding_player.is_ai:
		# 1. Use find_child to be safe, or check the exact name in your scene tree
		var ai_controller = bidding_player.find_child("AIController3D", true, false)
		
		if ai_controller:
			var fair_price = auction_property.tile_data.get("price", 100)
			if amount > fair_price * 1.2:
				# 2. Penalty for overbidding
				ai_controller.reward -= (amount - fair_price) * 0.01 

	current_bid = amount
	highest_bidder = bidding_player
	turn_index += 1
	_process_turn()
	

func fold_auction(): 
	if participants.is_empty(): return
	if turn_index >= participants.size(): turn_index = 0


	participants.remove_at(turn_index)
	if turn_index >= participants.size():
		turn_index = 0
	_process_turn()

func _end_auction(winner): 
	if ui.has_method("hide_auction_panel"):
		ui.hide_auction_panel()
	auction_finished.emit(winner, auction_property, current_bid)
