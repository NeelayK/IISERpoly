extends AIController3D
class_name MonopolyAIController

var gc
var my_player # The specific player this AI controls

# Constants for Neural Network Normalization
const MAX_MONEY_SCALE = 5000.0
const MAX_PLAYERS = 4
const MAX_TRADES_PER_ROUND = 3

# Action Enums for readability
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
	BANKRUPT = 14
}

func setup(game_controller, controlled_player):
	gc = game_controller
	my_player = controlled_player
	# Call _dump_static_env_data() elsewhere, like in GameController, 
	# as AIController3D focuses on step-by-step state now.

# ==========================================
# 1. ACTION SPACE (Defining what Python can output)
# ==========================================
func get_action_space() -> Dictionary:
	# This tells Python the shape of the output it needs to send back.
	# discrete: [ActionType, TargetPlayer, GivePropertyIdx, TakePropertyIdx]
	# continuous: [BidRatio, OfferCashRatio, DemandCashRatio] (Values from -1.0 to 1.0)
	return {
		"discrete": [15, MAX_PLAYERS, 40, 40],
		"continuous": 3
	}

# ==========================================
# 2. OBSERVATION SPACE (What Python sees)
# ==========================================
func get_obs() -> Dictionary:
	var obs: PackedFloat32Array = PackedFloat32Array()
	
	# --- A. GAME STATE & SELF-AWARENESS ---
	obs.append(float(gc.game_state) / 15.0) # Normalized game state
	var is_my_turn = 1.0 if gc.players[gc.current_player] == my_player else 0.0
	obs.append(is_my_turn)
	obs.append(1.0 if gc.is_reviewing_trade else 0.0)
	obs.append(float(gc.trade_requests) / float(MAX_TRADES_PER_ROUND))
	
	# --- B. ACTION MASK (What is legal right now? 1 = Yes, 0 = No) ---
	# Python uses these 15 floats to learn which of the 15 actions are valid
	var mask = _generate_action_mask()
	obs.append_array(mask)
	
	# --- C. MY PLAYER DATA ---
	obs.append(log(1.0 + max(0, my_player.money)) / log(1.0 + MAX_MONEY_SCALE))
	obs.append(float(my_player.current_tile) / 39.0)
	obs.append(1.0 if my_player.is_in_jail else 0.0)
	obs.append(float(my_player.jail_turns) / 3.0)
	obs.append(1.0 if my_player.jail_free_cards > 0 else 0.0)
	obs.append(1.0 if my_player.is_bankrupt else 0.0)
	obs.append(1.0 if gc.game_state == gc.GameState.LIQUIDATION and is_my_turn else 0.0) # Liquidation check
	
	# --- D. OPPONENT DATA (Padded to MAX_PLAYERS) ---
	for i in range(MAX_PLAYERS):
		if i < gc.players.size():
			var p = gc.players[i]
			if p == my_player:
				obs.append_array([0.0, 0.0, 0.0, 0.0]) # Skip self
			else:
				obs.append(log(1.0 + max(0, p.money)) / log(1.0 + MAX_MONEY_SCALE))
				obs.append(float(p.current_tile) / 39.0)
				obs.append(1.0 if p.is_in_jail else 0.0)
				obs.append(1.0 if p.is_bankrupt else 0.0)
		else:
			obs.append_array([0.0, 0.0, 0.0, 0.0]) # Ghost slots

	# --- E. BOARD STATE (40 Tiles) ---
	for t in gc.tiles:
		# Ownership: 1.0 (Me), 0.0 (Unowned), -1.0 (Opponent)
		if t.tile_owner == my_player: obs.append(1.0)
		elif t.tile_owner == null: obs.append(0.0)
		else: obs.append(-1.0)
			
		obs.append(1.0 if t.get("is_mortgaged", false) else 0.0)
		
		# Houses (0.0 to 1.0, where 1.0 is a hotel)
		obs.append(float(t.get("house_count", 0)) / 5.0)
		
		# Monopolies (Including Railroads/Cafes)
		obs.append(1.0 if t.get("is_monopoly", false) else 0.0)

	return {"obs": obs}

# ==========================================
# 3. EXECUTING ACTIONS (Handling Python's Decision)
# ==========================================
func set_action(action: Dictionary) -> void:
	# Python sends back the Dict shape we defined in get_action_space()
	var discrete = action.get("discrete", [0, 0, 0, 0])
	var continuous = action.get("continuous", [0.0, 0.0, 0.0])
	
	var act_type = discrete[0]
	var target_p_idx = discrete[1]
	var give_prop_idx = discrete[2]
	var take_prop_idx = discrete[3]
	
	# Continuous values come in as -1.0 to 1.0. We normalize them to 0.0 to 1.0
	var bid_ratio = (continuous[0] + 1.0) / 2.0
	var offer_cash_ratio = (continuous[1] + 1.0) / 2.0
	var demand_cash_ratio = (continuous[2] + 1.0) / 2.0
	
	# Only execute if it's our turn OR we are in an active trade/auction involving us
	var is_my_turn = (gc.players[gc.current_player] == my_player)
	
	match act_type:
		Actions.DO_NOTHING:
			pass # Usually used when waiting for other players
			
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
			if gc.game_state == gc.GameState.AUCTION:
				# Calculate bid amount based on AI's ratio choice vs its total money
				var bid_amt = max(gc.auction_manager.current_bid + 1, int(bid_ratio * my_player.money))
				gc.auction_manager.place_bid(bid_amt)
				
		Actions.FOLD_AUCTION:
			if gc.game_state == gc.GameState.AUCTION:
				gc.auction_manager.fold_auction()
				
		Actions.END_TURN:
			if is_my_turn and gc.game_state == gc.GameState.TURN_ACTIONS:
				gc._end_turn()
				
		Actions.PROPOSE_TRADE:
			if is_my_turn and gc.game_state == gc.GameState.TURN_ACTIONS and gc.trade_requests < MAX_TRADES_PER_ROUND:
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

# ==========================================
# UTILITIES
# ==========================================
# ==========================================
# UTILITIES & LEGAL MOVES (ACTION MASK)
# ==========================================
func _generate_action_mask() -> Array:
	var mask = []
	mask.resize(15)
	mask.fill(0.0) # Default: EVERYTHING is illegal
	
	var is_my_turn = (gc.players[gc.current_player] == my_player)
	
	# Always allow DO_NOTHING (Fallback state)
	mask[Actions.DO_NOTHING] = 1.0
	
	if is_my_turn:
		# --- ROLLING & JAIL ---
		if gc.game_state == gc.GameState.WAITING_ROLL:
			mask[Actions.ROLL] = 1.0
			if my_player.is_in_jail:
				if my_player.money >= gc.JAIL_FINE:
					mask[Actions.PAY_JAIL] = 1.0
				if my_player.jail_free_cards > 0:
					mask[Actions.USE_JAIL_CARD] = 1.0
				
		# --- BUYING PROPERTIES ---
		if gc.game_state == gc.GameState.PROPERTY_DECISION:
			var current_tile = gc.tiles[my_player.current_tile]
			var tile_price = current_tile.tile_data.get("price", 0)
			
			# ILLEGAL MOVE FIX: Can only buy if they have enough cash
			if my_player.money >= tile_price:
				mask[Actions.BUY_PROPERTY] = 1.0
				
			mask[Actions.AUCTION_PROPERTY] = 1.0 # Always an option to pass it to auction
			
		# --- TURN ACTIONS (Trading, Building) ---
		if gc.game_state == gc.GameState.TURN_ACTIONS:
			mask[Actions.END_TURN] = 1.0
			
			# Only allow trading if we haven't hit the limit AND there's a valid target
			if gc.trade_requests < MAX_TRADES_PER_ROUND:
				var can_trade = false
				for p in gc.players:
					if p != my_player and not p.is_bankrupt:
						can_trade = true
						break
				if can_trade:
					mask[Actions.PROPOSE_TRADE] = 1.0
			
			# Only allow Build/Mortgage if they actually own properties
			if my_player.properties.size() > 0:
				mask[Actions.MORTGAGE_TOGGLE] = 1.0
				mask[Actions.BUILD_HOUSE] = 1.0
				
		# --- BANKRUPTCY ---
		if gc.game_state == gc.GameState.LIQUIDATION:
			mask[Actions.BANKRUPT] = 1.0
			
	# --- REACTIONS (Can happen on other people's turns) ---
	
	# ILLEGAL MOVE FIX: Auctions
	if gc.game_state == gc.GameState.AUCTION:
		# Can only place a bid if their total money is higher than the current bid
		if my_player.money > gc.auction_manager.current_bid:
			mask[Actions.PLACE_BID] = 1.0
		mask[Actions.FOLD_AUCTION] = 1.0
		
	# ILLEGAL MOVE FIX: Trading
	if gc.is_reviewing_trade and gc.ui.current_trade.p2 == my_player:
		mask[Actions.ACCEPT_TRADE] = 1.0
		mask[Actions.DECLINE_TRADE] = 1.0
		
	return mask
	
# ==========================================
# REWARD SIGNAL (The Brain's Dopamine)
# ==========================================
func get_reward() -> float:
	var reward = 0.0
	
	# 1. Calculate Total Net Worth
	var property_value = 0.0
	var monopoly_count = 0
	
	for t in my_player.properties:
		# Properties are inherently valuable (we use mortgage value as baseline)
		property_value += t.tile_data.get("price", 0) / 2.0
		
		# Houses add value
		property_value += t.get("house_count", 0) * 50.0
		
		# Count monopolies
		if t.get("is_monopoly", false):
			monopoly_count += 1

	var net_worth = my_player.money + property_value
	
	# 2. Dense Reward: Small drip for maintaining wealth (scaled so it doesn't break the math)
	# The higher their net worth, the higher their baseline score
	reward += (net_worth / MAX_MONEY_SCALE) * 0.01
	
	# 3. Strategy Reward: Bonus for holding Monopolies
	# This naturally encourages the AI to trade and bid aggressively in auctions 
	# to complete sets, without us hard-coding "trading = good".
	reward += monopoly_count * 0.05
	
	# 4. Terminal Penalty
	if my_player.is_bankrupt:
		reward -= 1.0 # Huge penalty to teach it to avoid bankruptcy at all costs
		
	return reward
