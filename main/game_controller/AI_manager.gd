extends AIController3D
class_name MonopolyAIController

var gc
var my_player

const MAX_MONEY_SCALE = 5000.0
const MAX_PLAYERS = 6
const MAX_TRADES_PER_ROUND = 3

enum Actions {
	DO_NOTHING = 0,
	ROLL = 1,
	BUY_PROPERTY = 2,
	AUCTION_PROPERTY = 3,
	PLACE_BID = 4,
	FOLD_AUCTION = 5,
	END_TURN = 6,
	PAY_JAIL = 7,
	USE_JAIL_CARD = 8,
	PROPOSE_TRADE = 9,
	ACCEPT_TRADE = 10,
	DECLINE_TRADE = 11,
	BUILD_HOUSE = 12,
	MORTGAGE_TOGGLE = 13,
	BANKRUPT = 14,
	SWAP_MONEY = 15,
	SWAP_PROPERTY = 16,
	STEAL_PROPERTY = 17,
	SKIP_TURN = 18
}

func setup(game_controller, controlled_player):
	gc = game_controller
	my_player = controlled_player

func get_action_space() -> Dictionary:
	# Bypassing Godot-RL limitations: We ask for 7 continuous floats [-1.0 to 1.0]
	# We will manually map them to our discrete/ratio values in set_action()
	return {
		"monopoly_actions": {
			"action_type": "continuous",
			"size": 7
		}
	}

func get_obs() -> Dictionary:
	var obs: PackedFloat32Array = PackedFloat32Array()
	
	obs.append(float(gc.game_state) / 20.0)
	var is_my_turn = 1.0 if gc.players[gc.current_player] == my_player else 0.0
	obs.append(is_my_turn)
	obs.append(1.0 if gc.is_reviewing_trade else 0.0)
	obs.append(float(gc.trade_requests) / float(MAX_TRADES_PER_ROUND))
	
	var mask = _generate_action_mask()
	obs.append_array(mask)
	
	obs.append(log(1.0 + max(0, my_player.money)) / log(1.0 + MAX_MONEY_SCALE))
	obs.append(float(my_player.current_tile) / 39.0)
	obs.append(1.0 if my_player.is_in_jail else 0.0)
	obs.append(float(my_player.jail_turns) / 3.0)
	obs.append(1.0 if my_player.jail_free_cards > 0 else 0.0)
	obs.append(1.0 if my_player.is_bankrupt else 0.0)
	obs.append(1.0 if gc.game_state == gc.GameState.LIQUIDATION and is_my_turn else 0.0)
	
	for i in range(MAX_PLAYERS):
		if i < gc.players.size():
			var p = gc.players[i]
			if p == my_player:
				obs.append_array([0.0, 0.0, 0.0, 0.0])
			else:
				obs.append(log(1.0 + max(0, p.money)) / log(1.0 + MAX_MONEY_SCALE))
				obs.append(float(p.current_tile) / 39.0)
				obs.append(1.0 if p.is_in_jail else 0.0)
				obs.append(1.0 if p.is_bankrupt else 0.0)
		else:
			obs.append_array([0.0, 0.0, 0.0, 0.0])

	for t in gc.tiles:
		if t.tile_owner == my_player:
			obs.append(1.0)
		elif t.tile_owner == null:
			obs.append(0.0)
		else:
			obs.append(-1.0)
				
		var is_mort = t.get("is_mortgaged")
		obs.append(1.0 if is_mort == true else 0.0)
			
		var houses = t.get("house_count")
		if houses != null:
			obs.append(float(houses) / 5.0)
		else:
			obs.append(0.0)
				
		var is_mono = t.get("is_monopoly")
		obs.append(1.0 if is_mono == true else 0.0)

	return {"obs": obs}

# Helper to map continuous [-1.0, 1.0] to a discrete integer [0, max_size - 1]
func _get_discrete_from_float(val: float, max_size: int) -> int:
	var normalized = (clamp(val, -1.0, 1.0) + 1.0) / 2.0
	var index = int(round(normalized * (max_size - 1)))
	return clamp(index, 0, max_size - 1)

# Helper to map continuous [-1.0, 1.0] to a ratio [0.0, 1.0]
func _get_ratio_from_float(val: float) -> float:
	return (clamp(val, -1.0, 1.0) + 1.0) / 2.0

func set_action(action: Dictionary) -> void:
	var act_array = action.get("monopoly_actions")
	
	if act_array == null or act_array.size() < 7:
		return # Safety check

	# Snap the neural network's floats into our exact integer indices
	var act_type = _get_discrete_from_float(act_array[0], 19)
	var target_p_idx = _get_discrete_from_float(act_array[1], MAX_PLAYERS)
	var give_prop_idx = _get_discrete_from_float(act_array[2], 40)
	var take_prop_idx = _get_discrete_from_float(act_array[3], 40)
	
	# Smooth conversion for ratios
	var bid_ratio = _get_ratio_from_float(act_array[4])
	var offer_cash_ratio = _get_ratio_from_float(act_array[5])
	var demand_cash_ratio = _get_ratio_from_float(act_array[6])
	
	var is_my_turn = (gc.players[gc.current_player] == my_player)
	
	match act_type:
		Actions.DO_NOTHING:
			pass
			
		Actions.ROLL:
			if is_my_turn and gc.game_state == gc.GameState.WAITING_ROLL:
				gc._roll_pressed()
				
		Actions.BUY_PROPERTY:
			if is_my_turn and gc.game_state == gc.GameState.PROPERTY_DECISION:
				gc._buy_property()
				
		Actions.AUCTION_PROPERTY:
			if is_my_turn and gc.game_state == gc.GameState.PROPERTY_DECISION:
				gc._start_auction()
				
		Actions.PLACE_BID:
					if gc.game_state == gc.GameState.AUCTION and not gc.auction_manager.participants.is_empty():
						# --- NEW SAFETY CHECK HERE ---
						if gc.auction_manager.turn_index < gc.auction_manager.participants.size():
							var active_bidder = gc.auction_manager.participants[gc.auction_manager.turn_index]
							if my_player == active_bidder:
								var bid_amt = max(gc.auction_manager.current_bid + 1, int(bid_ratio * my_player.money))
								gc.auction_manager.place_bid(bid_amt)
				
		Actions.FOLD_AUCTION:
			if gc.game_state == gc.GameState.AUCTION and not gc.auction_manager.participants.is_empty():
				# --- NEW SAFETY CHECK HERE ---
				if gc.auction_manager.turn_index < gc.auction_manager.participants.size():
					var active_bidder = gc.auction_manager.participants[gc.auction_manager.turn_index]
					if my_player == active_bidder:
						gc.auction_manager.fold_auction()
				
		Actions.END_TURN:
			if is_my_turn and gc.game_state == gc.GameState.TURN_ACTIONS:
				gc._end_turn()
				
		Actions.PROPOSE_TRADE:
			if is_my_turn and gc.game_state == gc.GameState.TURN_ACTIONS and gc.trade_requests < MAX_TRADES_PER_ROUND:
				if target_p_idx >= 0 and target_p_idx < gc.players.size():
					var offer_cash_amount = int(offer_cash_ratio * my_player.money)
					var demand_cash_amount = int(demand_cash_ratio * gc.players[target_p_idx].money)
					gc.ai_propose_trade(target_p_idx, give_prop_idx, take_prop_idx, offer_cash_amount, demand_cash_amount)
						
		Actions.ACCEPT_TRADE:
			if gc.is_reviewing_trade and gc.ui.current_trade.p2 == my_player:
				gc._execute_trade()
				
		Actions.DECLINE_TRADE:
			if gc.is_reviewing_trade and gc.ui.current_trade.p2 == my_player:
				gc._cancel_trade()
				
		Actions.BANKRUPT:
			if is_my_turn and gc.game_state == gc.GameState.LIQUIDATION:
				gc._declare_bankruptcy()

		Actions.SWAP_MONEY:
			if is_my_turn and gc.game_state == gc.GameState.SWAP_SELECT_PLAYER:
				if target_p_idx >= 0 and target_p_idx < gc.players.size() and target_p_idx != gc.current_player:
					gc._execute_money_swap(my_player, gc.players[target_p_idx])
					gc.game_state = gc.GameState.TURN_ACTIONS
					
		Actions.SWAP_PROPERTY:
			if is_my_turn and gc.game_state == gc.GameState.SWAP_PROPERTIES:
				if target_p_idx >= 0 and target_p_idx < gc.players.size():
					gc._execute_property_swap(my_player, gc.tiles[give_prop_idx], gc.players[target_p_idx], gc.tiles[take_prop_idx])
					gc.game_state = gc.GameState.TURN_ACTIONS

		Actions.STEAL_PROPERTY:
			if is_my_turn and gc.game_state == gc.GameState.STEAL_PROPERTY:
				if target_p_idx >= 0 and target_p_idx < gc.players.size():
					gc._execute_property_steal(my_player, gc.players[target_p_idx], gc.tiles[take_prop_idx])
					gc.game_state = gc.GameState.TURN_ACTIONS

		Actions.SKIP_TURN:
			if is_my_turn and gc.game_state == gc.GameState.SKIP_OTHER_TURN:
				if target_p_idx >= 0 and target_p_idx < gc.players.size() and target_p_idx != gc.current_player:
					gc._execute_skip_turn(gc.players[target_p_idx])
					gc.game_state = gc.GameState.TURN_ACTIONS

func _generate_action_mask() -> Array:
	var mask = []
	mask.resize(19)
	mask.fill(0.0)
	
	var is_my_turn = (gc.players[gc.current_player] == my_player)
	mask[Actions.DO_NOTHING] = 1.0
	
	if is_my_turn:
		if gc.game_state == gc.GameState.WAITING_ROLL:
			mask[Actions.ROLL] = 1.0
			if my_player.is_in_jail:
				if my_player.money >= gc.JAIL_FINE:
					mask[Actions.PAY_JAIL] = 1.0
				if my_player.jail_free_cards > 0:
					mask[Actions.USE_JAIL_CARD] = 1.0
				
		if gc.game_state == gc.GameState.PROPERTY_DECISION:
			var current_tile = gc.tiles[my_player.current_tile]
			var tile_price = current_tile.tile_data.get("price", 0)
			
			if my_player.money >= tile_price:
				mask[Actions.BUY_PROPERTY] = 1.0
			mask[Actions.AUCTION_PROPERTY] = 1.0
			
		if gc.game_state == gc.GameState.TURN_ACTIONS:
			mask[Actions.END_TURN] = 1.0
			
			if gc.trade_requests < MAX_TRADES_PER_ROUND:
				var can_trade = false
				for p in gc.players:
					if p != my_player and not p.is_bankrupt:
						can_trade = true
						break
				if can_trade:
					mask[Actions.PROPOSE_TRADE] = 1.0
			
			if my_player.properties.size() > 0:
				mask[Actions.MORTGAGE_TOGGLE] = 1.0
				mask[Actions.BUILD_HOUSE] = 1.0
				
		if gc.game_state == gc.GameState.LIQUIDATION:
			mask[Actions.BANKRUPT] = 1.0

		if gc.game_state == gc.GameState.SWAP_SELECT_PLAYER:
			mask[Actions.SWAP_MONEY] = 1.0

		if gc.game_state == gc.GameState.SWAP_PROPERTIES:
			mask[Actions.SWAP_PROPERTY] = 1.0

		if gc.game_state == gc.GameState.STEAL_PROPERTY:
			mask[Actions.STEAL_PROPERTY] = 1.0

		if gc.game_state == gc.GameState.SKIP_OTHER_TURN:
			mask[Actions.SKIP_TURN] = 1.0
			
	if gc.game_state == gc.GameState.AUCTION and not gc.auction_manager.participants.is_empty():
		if gc.auction_manager.turn_index < gc.auction_manager.participants.size():
			var active_bidder = gc.auction_manager.participants[gc.auction_manager.turn_index]
			if my_player == active_bidder:
				if my_player.money > gc.auction_manager.current_bid:
					mask[Actions.PLACE_BID] = 1.0
				mask[Actions.FOLD_AUCTION] = 1.0
		
	if gc.is_reviewing_trade and gc.ui.current_trade != null and gc.ui.current_trade.p2 == my_player:
		mask[Actions.ACCEPT_TRADE] = 1.0
		mask[Actions.DECLINE_TRADE] = 1.0
		
	return mask
	
func get_reward() -> float:
	var reward = 0.0
	var property_value = 0.0
	var monopoly_count = 0
	
	for t in my_player.properties:
		# tile_data is a Dictionary, so 2 arguments (key, default) is fine here
		property_value += t.tile_data.get("price", 0) / 2.0
		
		# t is an Object (Node3D), so get() only takes 1 argument
		var houses = t.get("house_count")
		if houses != null:
			property_value += float(houses) * 50.0
			
		var is_mono = t.get("is_monopoly")
		if is_mono == true:
			monopoly_count += 1

	var net_worth = my_player.money + property_value
	
	reward += (net_worth / MAX_MONEY_SCALE) * 0.01
	reward += monopoly_count * 0.05
	
	if my_player.is_bankrupt:
		reward -= 1.0
		
	return reward
