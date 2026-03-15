#AuctionManager
#Handles Auction Functionality.

extends Node
class_name AuctionManager

signal auction_finished(winner, property, final_price)

var ui: CanvasLayer
var auction_property = null
var participants = []
var current_bid = 0
var highest_bidder = null
var turn_index = 0 # index of players in auction

func setup(main_ui: CanvasLayer): #Setup funtion called in GC (parent)
	ui = main_ui

func start_auction(property, all_players: Array): #Initial State for Auction
	auction_property = property
	participants = all_players.duplicate()
	current_bid = 0
	highest_bidder = null
	turn_index = 0
	_process_turn()

func _process_turn(): #Continuous State Check for Auction
	if participants.size() == 1 and highest_bidder != null:
		_end_auction(participants[0])
		return
		
	if participants.size() < 1:
		_end_auction(null)
		return

	if turn_index >= participants.size():
		turn_index = 0

	var bidding_player = participants[turn_index]
	var minimum_bid = current_bid + 50

	if bidding_player.money < minimum_bid:
		fold_auction()
		return

	ui.show_auction_panel(bidding_player, auction_property, current_bid, highest_bidder, place_bid, fold_auction)

func place_bid(amount: int): #Place Bid
	var bidding_player = participants[turn_index]
	if amount <= current_bid or amount > bidding_player.money: return

	current_bid = amount
	highest_bidder = bidding_player
	turn_index += 1
	_process_turn()

func fold_auction(): #Remove Player
	participants.remove_at(turn_index)
	if turn_index >= participants.size():
		turn_index = 0
	_process_turn()

func _end_auction(winner): #Function to emit winner [auction_finished(winner,property, bid_value)]
	ui.hide_auction_panel()
	auction_finished.emit(winner, auction_property, current_bid)
