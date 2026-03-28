extends Node3D

# ==========================================
# DEPENDENCIES & NODES
# ==========================================
@export var player_scene : PackedScene
@export var dice_controller : Node
@export var board_state : Node
@export var ui : CanvasLayer
@export var ai_controller: PackedScene
@export var ai_controllers: Array[MonopolyAIController]

@onready var auction_manager = $AuctionManager
@onready var property_manager = $PropertyManager
@onready var card_manager = $CardManager
@onready var ai_manager =  $AIManager

# ==========================================
# CONSTANTS & ENUMS
# ==========================================
var PLAYER_COUNT = GameConfig.player_data.size()
const JAIL_INDEX := 10
const JAIL_FINE := 50
const PLAYER_SCALE = 0.3
const MAX_JAIL_TURNS := 4

enum GameState {
	WAITING_ROLL, PLAYER_MOVING, PROPERTY_DECISION, TURN_ACTIONS,
	AUCTION, SELECTING_TILE, LIQUIDATION,
	SWAP_SELECT_PLAYER, SWAP_PROPERTIES, STEAL_PROPERTY, TRADING, SKIP_OTHER_TURN
}

# ==========================================
# VARIABLES
# ==========================================
var game_state = GameState.WAITING_ROLL
var turn_id: int = 0
var current_player := 0
var players = []
var tiles = []

# Dice & Turn States
var doubles_count = 0
var rolled_doubles := false
var latest_die_sum := 0
var game_started := false

# Selection & Trading
var selected_own_tile = null
var selected_target_tile = null
var current_action_mode = ""
var trade_requests := 0
var is_reviewing_trade := false

# Economy / AI
var library_reward := 0
var active_ai_controllers: Array[MonopolyAIController] = []

# ==========================================
# INITIALIZATION & SETUP
# ==========================================
func _ready():
	await get_tree().process_frame
	randomize()
	
	# Setup Managers
	auction_manager.setup(self, ui)
	auction_manager.auction_finished.connect(_on_auction_finished)
	property_manager.setup(board_state)
	card_manager.setup(self)
	
	# UI Connections
	ui.player_hovered.connect(_on_player_ui_hovered)
	ui.player_unhovered.connect(_on_player_ui_unhovered)
	ui.trade_accepted.connect(_on_trade_button_pressed)
	ui.trade_cancelled.connect(_cancel_trade)
	ui.trade_started.connect(func(player): start_trade_with(player))
	
	# Dice Connection
	dice_controller.connect("dice_result", _on_dice_result)
	
	# Board Setup
	tiles = board_state.get_tiles()
	for t in tiles:
		t.tile_clicked.connect(_on_tile_clicked)
		t.set_highlight(false)
		
	spawn_players()
	setup_ai_players()
	ui.setup_players(players)
	
	# Sync Node Initialization
	var sync_node = get_tree().get_first_node_in_group("rl_sync")
	if not sync_node:
		sync_node = find_child("Sync")
		
	if sync_node:
		sync_node._initialize()
		print("[DEBUG] Sync node initialized. Waiting for Python...")
	else:
		push_error("Sync node not found! Make sure it's in the scene.")

	# Start Game
	if players.size() > 0:
		start_turn()
	game_started = true

func spawn_players():
	players.clear()
	var actual_count = GameConfig.player_data.size()
	for i in range(actual_count):
		var config = GameConfig.player_data[i]
		var new_player = player_scene.instantiate()
		
		add_child(new_player)
		new_player.player_index = i
		new_player.player_name = config["name"]
		new_player.is_ai = config["is_ai"]
		new_player.move_finished.connect(_on_player_move_finished)
		new_player.passed_go.connect(ui.update_ui)
		
		var player_mesh_instance = new_player.get_node("MeshInstance3D")
		player_mesh_instance.mesh = config["model"]
		var mat = StandardMaterial3D.new()
		mat.albedo_color = config["color"]
		player_mesh_instance.material_override = mat
		
		var start_tile = tiles[0]
		new_player.global_position = start_tile.global_position + Vector3(0, 0.1, 0)
		players.append(new_player)
		
	_on_player_move_finished()

func setup_ai_players():
	active_ai_controllers.clear()
	for player in players:
		if player.is_ai:
			var controller = ai_controller.instantiate() as MonopolyAIController
			ai_manager.add_child(controller)
			controller.setup(self, player)
			active_ai_controllers.append(controller)
			controller.add_to_group("agent")
			print("Spawned AI Controller for: ", player.player_name)

# ==========================================
# INPUT HANDLING
# ==========================================
func _input(event):
	if not get_tree().paused and game_started:
		var player = players[current_player]
		if player.is_ai:
			if event.is_action_pressed("action_pause"):
				ui.toggle_pause()
			return

		if event.is_action_pressed("action_roll") and game_state == GameState.WAITING_ROLL:
			if not player.is_in_jail:
				_roll_pressed()
				
		if event.is_action_pressed("action_pause"):
			ui.toggle_pause()
			return

# ==========================================
# TURN LOGIC & DICE
# ==========================================
func start_turn():
	turn_id += 1
	trade_requests = 0
	var current_turn_token = turn_id
	game_state = GameState.WAITING_ROLL
	var player = players[current_player]

	if player.is_bankrupt or player.skip_turn:
		if player.skip_turn: player.skip_turn = false
		_end_turn()
		return
		
	ui.update_turn_display(String(player.player_name) + "'s Turn ")
	
	if player.is_ai:
		if current_turn_token != turn_id: return
	else:
		if player.is_in_jail:
			var can_pay = player.money >= JAIL_FINE
			var has_card = player.jail_free_cards > 0
			ui.show_jail_buttons(_pay_jail_fine, _use_jail_card, _roll_pressed, can_pay, has_card)
		else:
			ui.show_roll_button(_roll_pressed)

func _end_turn():
	ui.clear_buttons()
	var player = players[current_player]
	
	if rolled_doubles and not player.is_bankrupt and not player.is_in_jail:
		start_turn()
		return
	
	doubles_count = 0
	rolled_doubles = false
	for t in tiles: t.set_highlight(false)

	var next_player_found = false
	var attempts = 0
	
	while not next_player_found and attempts < players.size():
		current_player = (current_player + 1) % players.size()
		attempts += 1
		
		if not players[current_player].is_bankrupt:
			next_player_found = true
			start_turn()
			return

func _roll_pressed():
	if game_state != GameState.WAITING_ROLL: return
	game_state = GameState.PLAYER_MOVING
	dice_controller.roll_dice()

func _on_dice_result(die1, die2):
	var dice_turn_token = turn_id
	latest_die_sum = abs(die1+die2)
	var player = players[current_player]
	
	if dice_turn_token != turn_id: return
	
	if player.is_in_jail:
		_handle_jail_roll(player, die1, die2)
		return

	if die1 == die2:
		doubles_count += 1
		rolled_doubles = true
		if doubles_count == 3:
			send_to_jail(player)
			return
	else:
		doubles_count = 0
		rolled_doubles = false
		
	if player.negative_dice:
		player.move_steps(-(die1 + die2), tiles)
		player.negative_dice = false
	else:
		player.move_steps(die1 + die2, tiles)
		
	if dice_turn_token == turn_id:
		resolve_tile(player)

# ==========================================
# PLAYER MOVEMENT & UI VISUALS
# ==========================================
func _on_player_move_finished():
	for tile_idx in range(tiles.size()):
		_rearrange_players_on_tile(tile_idx)

func _rearrange_players_on_tile(tile_idx: int):
	var players_on_this_tile = []
	for p in players:
		if p.current_tile == tile_idx:
			players_on_this_tile.append(p)
	
	var count = players_on_this_tile.size()
	var tile_pos = tiles[tile_idx].global_position
	for i in range(count):
		var offset = Vector3.ZERO
		if count > 1:
			var radius = 0.35
			var angle = i * (TAU / count)
			offset = Vector3(cos(angle) * radius, 0, sin(angle) * radius)
		# Assuming you apply this offset somewhere in actual movement

func _on_player_ui_hovered(player_index: int):
	if game_state == GameState.SELECTING_TILE: return
	var hovered_player = players[player_index]
	for t in tiles:
		if t.tile_owner == hovered_player: t.set_highlight(true, Color(0.016, 1.0, 0.914, 1.0))

func _on_player_ui_unhovered():
	if game_state == GameState.SELECTING_TILE: return
	for t in tiles:
		t.set_highlight(false)
	if game_state in [GameState.SWAP_PROPERTIES, GameState.STEAL_PROPERTY]:
		$CardManager._update_swap_highlights()

# ==========================================
# JAIL LOGIC
# ==========================================
func send_to_jail(player):
	player.is_in_jail = true
	player.jail_turns = 0
	doubles_count = 0
	rolled_doubles = false
	player.current_tile = JAIL_INDEX
	show_default_actions()

func _handle_jail_roll(player, die1, die2):
	player.jail_turns += 1
	if die1 == die2:
		player.is_in_jail = false
		player.jail_turns = 0
		start_turn()
	else:
		if player.jail_turns >= MAX_JAIL_TURNS:
			player.money -= JAIL_FINE
			player.is_in_jail = false
			player.jail_turns = 0
			ui.update_ui()
			player.move_steps(die1 + die2, tiles)
			resolve_tile(player)
		else:
			show_default_actions()

func _pay_jail_fine():
	players[current_player].money -= JAIL_FINE
	_free_from_jail()

func _use_jail_card():
	players[current_player].jail_free_cards -= 1
	_free_from_jail()

func _free_from_jail():
	players[current_player].is_in_jail = false
	players[current_player].jail_turns = 0
	ui.update_ui()
	start_turn()

# ==========================================
# PROPERTY & TILE RESOLUTION
# ==========================================
func resolve_tile(player):
	var tile = tiles[player.current_tile]
	ui.show_property_details(tile, library_reward)
	
	if player.current_tile == 30: # Go to Jail Tile
		send_to_jail(player)
		return
		
	if player.current_tile == 20: # Free Parking / Library
		player.money += library_reward
		library_reward = 0
		ui.update_ui()
		show_default_actions()
		return
		
	if tile.tile_type in [BoardData.TileType.PROPERTY, BoardData.TileType.CAFE, BoardData.TileType.UTILITY]:
		if tile.tile_owner == null:
			game_state = GameState.PROPERTY_DECISION
			if not player.is_ai:
				var can_buy = player.money >= tile.tile_data.get("price", 0)
				ui.show_property_buttons(_buy_property, _start_auction, can_buy)
				
		elif tile.tile_owner != player:
			if player.next_rent_free:
				player.next_rent_free = false
				ui.update_ui()
				check_liquidation(player)
				return
			var rent = board_state.calculate_rent(tile)
			player.money -= rent
			tile.tile_owner.money += rent
			ui.update_ui()
			check_liquidation(player)
		else:
			check_liquidation(player)
			
	elif tile.tile_type == BoardData.TileType.FEES:
		player.money -= tile.tile_data.get("price", 100)
		library_reward += tile.tile_data.get("price", 100)
		ui.update_ui()
		check_liquidation(player)
		
	elif tile.tile_type == BoardData.TileType.CHANCE:
		card_manager.handle_draw_card(player, true)
	elif tile.tile_type == BoardData.TileType.PROJECT_FUNDS:
		card_manager.handle_draw_card(player, false)
	else:
		check_liquidation(player)

func _buy_property():
	var player = players[current_player]
	var tile = tiles[player.current_tile]
	var price = tile.tile_data.get("price", 0)
	
	if price == 0: return
	
	player.money -= price
	player.properties.append(tile)
	tile.tile_owner = player
	
	update_all_monopolies() # <--- MONOPOLY CHECK INJECTED
	
	ui.update_ui()
	ui.show_property_details(tile, library_reward)
	show_default_actions()

func _start_auction():
	ui.clear_buttons()
	game_state = GameState.AUCTION
	auction_manager.start_auction(tiles[players[current_player].current_tile], players)

func _on_auction_finished(winner, property, final_price):
	if winner != null:
		winner.money -= final_price
		winner.properties.append(property)
		property.tile_owner = winner
		
		update_all_monopolies() # <--- MONOPOLY CHECK INJECTED
		
		ui.update_ui()
	show_default_actions()
	ui.show_property_details(property)

# ==========================================
# TURN ACTIONS & TILE SELECTION
# ==========================================
func show_default_actions(camera_pan: bool = true):
	game_state = GameState.TURN_ACTIONS
	var player = players[current_player]
	
	var buildable = []
	var sellable = []
	var mortgageable = []
	var unmortgageable = []
	
	for t in player.properties:
		if property_manager.is_valid_for_action(t, "build", player, tiles): buildable.append(t)
		if property_manager.is_valid_for_action(t, "sell", player, tiles): sellable.append(t)
		if property_manager.is_valid_for_action(t, "mortgage", player, tiles): mortgageable.append(t)
		if property_manager.is_valid_for_action(t, "unmortgage", player, tiles): unmortgageable.append(t)

	ui.show_turn_actions({
		"build": setup_tile_selection.bind("build", Color.GREEN),
		"sell": setup_tile_selection.bind("sell", Color.RED),
		"mortgage": setup_tile_selection.bind("mortgage", Color.ORANGE),
		"unmortgage": setup_tile_selection.bind("unmortgage", Color.YELLOW),
		"trade": _trade_possible,
		"end_turn": _end_turn
	})

func setup_tile_selection(mode: String, color: Color):
	game_state = GameState.SELECTING_TILE
	current_action_mode = mode
	var player = players[current_player]
	
	for t in tiles: t.set_highlight(false)
	for t in player.properties:
		if property_manager.is_valid_for_action(t, mode, player, tiles):
			t.set_highlight(true, color)

func _on_tile_clicked(tile):
	ui.show_property_details(tile, library_reward)
	var player = players[current_player]
	
	if game_state == GameState.SELECTING_TILE:
		if property_manager.is_valid_for_action(tile, current_action_mode, player, tiles):
			property_manager.execute_action(tile, current_action_mode, player)
			ui.show_property_details(tile, library_reward)
			ui.update_ui()
			for t in tiles: t.set_highlight(false)
			game_state = GameState.TURN_ACTIONS
		check_liquidation(player)
		
	elif game_state == GameState.TRADING and not is_reviewing_trade:
		if not tile.tile_type in [BoardData.TileType.PROPERTY, BoardData.TileType.CAFE, BoardData.TileType.UTILITY]:
			return
			
		if tile.tile_owner == ui.current_trade.p1 or tile.tile_owner == ui.current_trade.p2:
			if _color_group_has_funding(tile):
				return
			ui.toggle_trade_property(tile)
		return
	
	elif game_state in [GameState.SWAP_PROPERTIES, GameState.STEAL_PROPERTY]:
		if not tile.tile_type in [BoardData.TileType.PROPERTY, BoardData.TileType.UTILITY, BoardData.TileType.CAFE]:
			return
		
		if tile.tile_owner == player:
			if game_state == GameState.SWAP_PROPERTIES:
				var can_swap = true
				for t in tiles:
					if t.tile_type == BoardData.TileType.PROPERTY and t.tile_data.get("color") == tile.tile_data.get("color"):
						if t.funding > 0:
							can_swap = false
							break
				if can_swap:
					selected_own_tile = tile
		else:
			var t_color = tile.tile_data.get("color", "")
			if tile.tile_owner == null or not board_state.has_monopoly(tile.tile_owner, t_color):
				selected_target_tile = tile
			
		$CardManager._update_swap_highlights()
		
		if game_state == GameState.SWAP_PROPERTIES and selected_own_tile != null and selected_target_tile != null:
			ui.show_confirm_button("Confirm Swap", Callable($CardManager, "complete_action"))
			
		elif game_state == GameState.STEAL_PROPERTY and selected_target_tile != null:
			ui.show_confirm_button("Confirm Steal", Callable($CardManager, "complete_action"))

# ==========================================
# TRADING LOGIC
# ==========================================
func _trade_possible():
	if trade_requests < 3:
		ui.trade_selector(players, current_player)

func start_trade_with(target_player):
	game_state = GameState.TRADING
	ui.open_trade_panel(players[current_player], target_player)

func _color_group_has_funding(tile) -> bool:
	if tile.tile_type != BoardData.TileType.PROPERTY: return false
	var target_color = tile.tile_data.get("color", "")
	for t in tiles:
		if t.tile_type == BoardData.TileType.PROPERTY and t.tile_data.get("color", "") == target_color:
			if t.funding > 0:
				return true
	return false

func _on_trade_button_pressed():
	if not is_reviewing_trade:
		trade_requests += 1
		is_reviewing_trade = true
		ui.open_trade_review()
		ui.update_turn_display("Waiting for " + ui.current_trade.p2.player_name + "...")
	else:
		_execute_trade()

func _execute_trade():
	var p1 = ui.current_trade.p1
	var p2 = ui.current_trade.p2
	
	p1.money -= ui.p1_cash_input.value
	p2.money += ui.p1_cash_input.value
	p2.money -= ui.p2_cash_input.value
	p1.money += ui.p2_cash_input.value
	
	for t in ui.current_trade.p1_props:
		p1.properties.erase(t)
		p2.properties.append(t)
		t.tile_owner = p2
	for t in ui.current_trade.p2_props:
		p2.properties.erase(t)
		p1.properties.append(t)
		t.tile_owner = p1

	update_all_monopolies() # <--- MONOPOLY CHECK INJECTED

	is_reviewing_trade = false
	ui.close_trade_panel()
	ui.update_ui()
	show_default_actions()
	ui.update_turn_display(String(players[current_player].player_name) + "'s Turn ")
	game_state = GameState.TURN_ACTIONS

func _cancel_trade():
	is_reviewing_trade = false
	ui.close_trade_panel()
	show_default_actions()
	ui.update_turn_display(String(players[current_player].player_name) + "'s Turn ")
	game_state = GameState.TURN_ACTIONS

func ai_propose_trade(target_idx: int, give_prop_idx: int, take_prop_idx: int, offer_cash: int, demand_cash: int):
	var p1 = players[current_player]
	if target_idx < 0 or target_idx >= players.size() or target_idx == current_player: return
	
	var p2 = players[target_idx]
	if p2.is_bankrupt: return
	
	start_trade_with(p2)
	
	if give_prop_idx >= 0 and give_prop_idx < tiles.size():
		var give_tile = tiles[give_prop_idx]
		if give_tile.tile_owner == p1:
			ui.toggle_trade_property(give_tile)
			
	if take_prop_idx >= 0 and take_prop_idx < tiles.size():
		var take_tile = tiles[take_prop_idx]
		if take_tile.tile_owner == p2:
			ui.toggle_trade_property(take_tile)
			
	ui.p1_cash_input.value = clamp(offer_cash, 0, p1.money)
	ui.p2_cash_input.value = clamp(demand_cash, 0, p2.money)
	ui.update_trade_ui()
	
	var p1_giving = ui.current_trade.p1_props.size() > 0 or ui.p1_cash_input.value > 0
	var p2_giving = ui.current_trade.p2_props.size() > 0 or ui.p2_cash_input.value > 0
	
	if p1_giving and p2_giving:
		_on_trade_button_pressed()
	else:
		ui.close_trade_panel()
		game_state = GameState.TURN_ACTIONS

# ==========================================
# LIQUIDATION, BANKRUPTCY & RESET
# ==========================================
func check_liquidation(player):
	if player.money < 0:
		game_state = GameState.LIQUIDATION
		if player.is_ai:
			_declare_bankruptcy()
			return

		var sellable = []
		var mortgageable = []
		for t in player.properties:
			if property_manager.is_valid_for_action(t, "sell", player, tiles): sellable.append(t)
			if property_manager.is_valid_for_action(t, "mortgage", player, tiles): mortgageable.append(t)

		ui.show_turn_actions({
			"sell": setup_tile_selection.bind("sell", Color(1.0, 0.812, 0.85, 1.0)),
			"mortgage": setup_tile_selection.bind("mortgage", Color(0.841, 0.857, 1.0, 1.0)),
			"unmortgage": setup_tile_selection.bind("unmortgage", Color(1.0, 0.85, 0.5)),
			"trade": func(): ui.trade_selector(players, current_player),
			"end_turn": _declare_bankruptcy
		}, true)
	else:
		show_default_actions()

func _declare_bankruptcy():
	var player = players[current_player]
	for t in player.properties:
		t.tile_owner = null
		t.is_mortgaged = false
		t.funding = 0
		
	player.is_bankrupt = true
	player.properties.clear()
	player.visible = false
	
	update_all_monopolies() # <--- MONOPOLY CHECK INJECTED
	
	for t in tiles: t.set_highlight(false)
	ui.update_ui()
	
	if not _check_win_condition():
		_end_turn()

func _check_win_condition() -> bool:
	var active_players = []
	for p in players:
		if not p.is_bankrupt: active_players.append(p)

	if active_players.size() == 1:
		ui.update_turn_display(active_players[0].player_name + " WINS!")
		print("Winner is: ", active_players[0].player_name)
		call_deferred("reset_game")
		return true
	return false

func reset_game():
	
	for t in tiles:
		t.tile_owner = null
		if t.has_method("refresh_buildings"):
			t.funding = 0
			t.refresh_buildings()
			
	update_all_monopolies() # <--- MONOPOLY CHECK INJECTED
			
	for p in players:
		p.money = 1500
		p.is_bankrupt = false
		p.properties.clear()
		p.current_tile = 0
		p.skip_turn = false
		p.jail_free_cards = 0
		p.global_position = tiles[0].global_position + Vector3(0, 0.1, 0)
		
		var ai_ctrl = p.get_node_or_null("AIController3D")
		if ai_ctrl:
			if p == players[0]: ai_ctrl.reward += 10.0
			else: ai_ctrl.reward -= 10.0
			ai_ctrl.done = true
			ai_ctrl.needs_reset = true

	current_player = 0
	game_state = GameState.TURN_ACTIONS
	ui.clear_buttons()
	ui.update_ui()

# ==========================================
# AI ACTION WRAPPERS (Card Functions)
# ==========================================
func _execute_money_swap(p1, p2):
	card_manager._execute_money_swap(p1, p2)

func _execute_skip_turn(player):
	card_manager._execute_skip_turn(player)

func _execute_property_swap(p1, p1_tile, p2, p2_tile):
	p1.properties.erase(p1_tile)
	if p2 != null:
		p2.properties.erase(p2_tile)
		p2.properties.append(p1_tile)
		
	p1_tile.tile_owner = p2
	p2_tile.tile_owner = p1
	p1.properties.append(p2_tile)
	
	update_all_monopolies() # <--- MONOPOLY CHECK INJECTED
	
	if p1_tile.has_method("refresh_buildings"): p1_tile.refresh_buildings()
	if p2_tile.has_method("refresh_buildings"): p2_tile.refresh_buildings()
	ui.update_ui()

func _execute_property_steal(p1, p2, p2_tile):
	if p2 != null:
		p2.properties.erase(p2_tile)
		
	p2_tile.tile_owner = p1
	p1.properties.append(p2_tile)
	
	update_all_monopolies() # <--- MONOPOLY CHECK INJECTED
	
	if p2_tile.has_method("refresh_buildings"): p2_tile.refresh_buildings()
	ui.update_ui()

func ai_build_house(player, tile):
	if property_manager.is_valid_for_action(tile, "build", player, tiles):
		property_manager.execute_action(tile, "build", player)
		ui.update_ui()
		print("[AI] ", player.player_name, " built a house on ", tile.name)

func ai_toggle_mortgage(player, tile) -> float:
	if tile.is_mortgaged:
		if property_manager.is_valid_for_action(tile, "unmortgage", player, tiles):
			property_manager.execute_action(tile, "unmortgage", player)
			ui.update_ui()
			print("[AI] ", player.player_name, " UNMORTGAGED ", tile.name)
			return 0.15
	else:
		if property_manager.is_valid_for_action(tile, "mortgage", player, tiles):
			property_manager.execute_action(tile, "mortgage", player)
			ui.update_ui()
			print("[AI] ", player.player_name, " MORTGAGED ", tile.name)
			return -0.3
	return 0.0

# ==========================================
# HELPER FUNCTIONS
# ==========================================
func update_all_monopolies():
	for t in tiles:
		if t.tile_type == BoardData.TileType.PROPERTY:
			var t_color = t.tile_data.get("color", "")
			if t.tile_owner != null:
				# Ask board_state if this owner holds all properties of this color
				t.is_monopoly = board_state.has_monopoly(t.tile_owner, t_color)
			else:
				t.is_monopoly = false
