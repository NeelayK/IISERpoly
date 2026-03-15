extends Node3D

# --- Dependencies ---
@export var player_scene : PackedScene
@export var dice_controller : Node
@export var board_state : Node
@export var ui : CanvasLayer
@export var camera_rig : Node3D
@onready var auction_manager = $AuctionManager
@onready var property_manager = $PropertyManager
@onready var card_manager = $CardManager

# --- Constants ---
const PLAYER_COUNT := 2   
const JAIL_INDEX := 10
const JAIL_FINE := 50
const MAX_JAIL_TURNS := 3
const PLAYER_CONFIG = [
	{"name": "Player 1", "model": preload("res://assets/players/Art.obj")},
	{"name": "Player 2", "model": preload("res://assets/players/Knight.obj")},
	{"name": "Player 3", "model": preload("res://assets/players/Beaker.obj")},
	{"name": "Player 4", "model": preload("res://assets/players/Guitar.obj")},
	{"name": "Player 5", "model": preload("res://assets/players/Rocket.obj")},
	{"name": "Player 6", "model": preload("res://assets/players/Wolf.obj")}
] 

enum GameState { 
	WAITING_ROLL, PLAYER_MOVING, PROPERTY_DECISION, TURN_ACTIONS, 
	AUCTION, SELECTING_TILE, LIQUIDATION, 
	SWAP_SELECT_PLAYER, SWAP_PROPERTIES, STEAL_PROPERTY 
}


var selected_own_tile = null
var selected_target_tile = null
var latest_die_sum := 0
# --- State Variables ---
var game_state = GameState.WAITING_ROLL
var current_action_mode = ""
var players = []
var current_player = 0
var tiles = []
var doubles_count = 0
var rolled_doubles = false
var library_reward = 0

# ==========================================
# INITIALIZATION
# ==========================================
func _ready():
	await get_tree().process_frame
	
	# Setup Sub-Managers
	auction_manager.setup(ui)
	auction_manager.auction_finished.connect(_on_auction_finished)
	property_manager.setup(board_state)
	card_manager.setup(self)
	
	ui.player_hovered.connect(_on_player_ui_hovered)
	ui.player_unhovered.connect(_on_player_ui_unhovered)
	
	tiles = board_state.get_tiles()
	for t in tiles: t.tile_clicked.connect(_on_tile_clicked)
		
	spawn_players()
	ui.setup_players(players)
	dice_controller.connect("dice_result", _on_dice_result)
	
	start_turn()

func spawn_players():
	for i in range(PLAYER_COUNT):
		var data = PLAYER_CONFIG[i]
		var p = player_scene.instantiate()
		add_child(p)
		p.get_child(0).mesh = data["model"]
		p.get_child(0).scale = Vector3(0.3, 0.3, 0.3)
		p.player_name = data["name"]
		p.global_position = tiles[0].global_position + Vector3(i * 0.6, 0.1, 0)
		p.connect("passed_go",ui.update_ui)
		players.append(p)

# ==========================================
# TURN LOGIC & MOVEMENT
# ==========================================
func start_turn():
	game_state = GameState.WAITING_ROLL
	var player = players[current_player]
	print("\n--- ", player.player_name, "'s Turn ---")
	
	if player.is_in_jail:
		var can_pay = player.money >= JAIL_FINE
		var has_card = player.jail_free_cards > 0
		ui.show_jail_buttons(_pay_jail_fine, _use_jail_card, _roll_pressed, can_pay, has_card)
	else:
		ui.show_roll_button(_roll_pressed)

func _input(event):
	if event.is_action_pressed("ui_accept") and game_state == GameState.WAITING_ROLL:
		if not players[current_player].is_in_jail: _roll_pressed()

func _roll_pressed():
	if game_state != GameState.WAITING_ROLL: return
	game_state = GameState.PLAYER_MOVING
	camera_rig.show_dice()
	await get_tree().create_timer(0.5).timeout
	dice_controller.roll_dice()

func _on_dice_result(die1, die2):
	latest_die_sum = abs(die1+die2)
	var player = players[current_player]
	if camera_rig.has_method("look_at_player"): camera_rig.look_at_player(player)
	await get_tree().create_timer(1.0).timeout
	
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
		await player.move_steps(-(die1 + die2), tiles)
		player.negative_dice = false
	else:
		await player.move_steps(die1 + die2, tiles)
	resolve_tile(player)

func _end_turn():
	var player = players[current_player]
	if rolled_doubles and not player.is_in_jail:
		start_turn() 
	else:
		doubles_count = 0
		rolled_doubles = false
		current_player = (current_player + 1) % players.size()
		start_turn()

# ==========================================
# JAIL LOGIC
# ==========================================
func send_to_jail(player):
	player.is_in_jail = true
	player.jail_turns = 0
	doubles_count = 0
	rolled_doubles = false
	player.current_tile = JAIL_INDEX 
	player.global_position = tiles[JAIL_INDEX].global_position + Vector3(0, 0.1, 0)
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

func _handle_jail_roll(player, die1, die2):
	player.jail_turns += 1
	if die1 == die2:
		player.is_in_jail = false
		player.jail_turns = 0
		await player.move_steps(die1 + die2, tiles)
		resolve_tile(player)
	else:
		if player.jail_turns >= MAX_JAIL_TURNS:
			player.money -= JAIL_FINE
			player.is_in_jail = false
			player.jail_turns = 0
			ui.update_ui()
			await player.move_steps(die1 + die2, tiles)
			resolve_tile(player)
		else:
			show_default_actions()

# ==========================================
# TILE RESOLUTION & ACTIONS
# ==========================================
func resolve_tile(player):
	
	var tile = tiles[player.current_tile]
	ui.show_property_details(tile)
	
	if player.current_tile == 30: # Go to Jail
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
			ui.show_property_buttons(_buy_property, _start_auction, player.money >= tile.tile_data.get("price", 0))
		elif tile.tile_owner != player:
			if player.next_rent_free:
				print(player.player_name, " uses their Rent Free pass!")
				player.next_rent_free = false # Reset it so it only works once
				ui.update_ui()
				show_default_actions()
				return # Exit early, no money changes hands
			var rent = board_state.calculate_rent(tile)
			player.money -= rent
			tile.tile_owner.money += rent
			ui.update_ui()
			check_liquidation(player)
		else:
			show_default_actions()
			
	elif tile.tile_type == BoardData.TileType.FEES:
		player.money -= tile.tile_data.get("price", 100)
		library_reward += tile.tile_data.get("price", 100) 
		ui.update_ui()
		check_liquidation(player)
		
	elif tile.tile_type == BoardData.TileType.CHANCE:
		card_manager.handle_draw_card(player, true)
		
	# FIXED: This was checking for CHANCE twice in your original code
	elif tile.tile_type == BoardData.TileType.PROJECT_FUNDS: 
		card_manager.handle_draw_card(player, false)
		
	else:
		show_default_actions()



func _buy_property():
	var player = players[current_player]
	var tile = tiles[player.current_tile]
	player.money -= tile.tile_data.price
	player.properties.append(tile)
	tile.tile_owner = player
	ui.update_ui()
	ui.show_property_details(tile)
	show_default_actions()

func show_default_actions():
	game_state = GameState.TURN_ACTIONS
	var current_pos = players[current_player].global_position
	#camera_rig.enable_tabletop_pan(Vector3(current_pos.x, 0, current_pos.z))
	ui.show_turn_actions({
		"build": setup_tile_selection.bind("build", Color.GREEN),
		"sell": setup_tile_selection.bind("sell", Color.RED),
		"mortgage": setup_tile_selection.bind("mortgage", Color.ORANGE),
		"unmortgage": setup_tile_selection.bind("unmortgage", Color.YELLOW),
		"trade": func(): pass, # Placeholder
		"end_turn": _end_turn
	})

# ==========================================
# AUCTION DELEGATION
# ==========================================
func _start_auction():
	ui.clear_buttons()
	game_state = GameState.AUCTION
	auction_manager.start_auction(tiles[players[current_player].current_tile], players)

func _on_auction_finished(winner, property, final_price):
	if winner != null:
		winner.money -= final_price
		winner.properties.append(property)
		property.tile_owner = winner
		ui.update_ui()
	show_default_actions()

# ==========================================
# PROPERTY SELECTION DELEGATION
# ==========================================
func setup_tile_selection(mode: String, color: Color):
	game_state = GameState.SELECTING_TILE
	current_action_mode = mode
	var player = players[current_player]
	for t in tiles: t.set_highlight(false)
	for t in player.properties:
		if property_manager.is_valid_for_action(t, mode, player, tiles):
			t.set_highlight(true, color)



func _on_tile_clicked(tile):
	ui.show_property_details(tile)
	var player = players[current_player]
	if game_state == GameState.SELECTING_TILE:
		if property_manager.is_valid_for_action(tile, current_action_mode, player, tiles):
			property_manager.execute_action(tile, current_action_mode, player)
			
			# Special refresh for grouped utilities/cafes
			if tile.tile_type in [BoardData.TileType.CAFE, BoardData.TileType.UTILITY]:
				for t in tiles:
					if t.tile_type == tile.tile_type and t.tile_owner == player: t.refresh_buildings()
			
			ui.show_property_details(tile)
			ui.update_ui()
			for t in tiles: t.set_highlight(false)
			game_state = GameState.TURN_ACTIONS
		check_liquidation(player)
	elif game_state in [GameState.SWAP_PROPERTIES, GameState.STEAL_PROPERTY]:
		if not tile.tile_type in [BoardData.TileType.PROPERTY, BoardData.TileType.UTILITY, BoardData.TileType.CAFE]:
			return
		
		if tile.tile_owner == player:
			if game_state == GameState.SWAP_PROPERTIES:
				# Local check for buildings (funding) to prevent selecting
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
# BANKRUPTCY & UI HIGHLIGHTS
# ==========================================
func check_liquidation(player):
	if player.money < 0:
		game_state = GameState.LIQUIDATION
		ui.show_turn_actions({
			"build": func(): pass, "sell": setup_tile_selection.bind("sell", Color.RED),
			"mortgage": setup_tile_selection.bind("mortgage", Color.ORANGE), "unmortgage": func(): pass,
			"trade": func(): pass, "end_turn": _declare_bankruptcy 
		})
		if ui.has_method("disable_unusable_liquidation_buttons"): ui.disable_unusable_liquidation_buttons()
	else:
		show_default_actions()

func _declare_bankruptcy():
	var player = players[current_player]
	for t in player.properties:
		t.tile_owner = null
		t.is_mortgaged = false
		t.funding = 0
		t.refresh_buildings()
	player.is_bankrupt = true
	player.properties.clear()
	player.visible = false 
	_end_turn()

func _on_player_ui_hovered(player_index: int):
	if game_state == GameState.SELECTING_TILE: return 
	var hovered_player = players[player_index]
	for t in tiles:
		if t.tile_owner == hovered_player: t.set_highlight(true, Color.CYAN)

func _on_player_ui_unhovered():
	if game_state == GameState.SELECTING_TILE: return
	for t in tiles: 
		t.set_highlight(false)
	if game_state in [GameState.SWAP_PROPERTIES, GameState.STEAL_PROPERTY]:
		$CardManager._update_swap_highlights()
