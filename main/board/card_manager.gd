extends Node3D

var gc : Node3D
@onready var board_state := $"../../Board/BoardState"
@onready var ui := $"../../UI"
@onready var camera :=$"../../CameraRIG"

#region Card Data

const chance_cards := [
	{"text": "You reported someone for harassment.", "type": "skip_other_turn"},
	{"text": "You are hit by a football! Skip a turn.", "type": "skip_turn"},
	{"text": "Identity fraud! Your ID card gets swapped. Swap a property.", "type": "swap_property"},
	{"text": "You sat in the wrong exam hall. Roll Negative Dice.", "type": "negative_dice"},
	{"text": "Director catches you for not walking on the footpath. Go back 3 spaces.", "type": "move", "value": -3},
	{"text": "You bunk classes. Advance to the Library and collect the library reward.", "type": "move_to", "target": 20},
	{"text": "You are caught misusing the water filter. Pay a fine of 50.", "type": "pay", "value": 50},
	{"text": "Ishya celebrations begin! Advance to the Indoor Stadium.", "type": "move_to", "target": 11},
	{"text": "The Director participates in a sports fest. Advance to the Volleyball Court.", "type": "move_to", "target": 8},

	{"text": "Class cancelled! Take an extra turn.", "type": "extra_turn"},
	{"text": "UPI payment system is down. Pay 30 in cash.", "type": "pay", "value": 30},
	{"text": "Floor WiFi is down. Go back to CDH 2.", "type": "move_to", "target": 18},
	{"text": "You break your left phalange at the gym. Go back 6 spaces.", "type": "move", "value": -6},
	{"text": "Someone at iCafe ate your sandwich. Collect 50 from everyone.", "type": "collect_all", "value": 50},
	{"text": "You discover how to burn vegetable soup faster than stir-fried vegetables. Biology Block awards you 150.", "type": "collect", "value": 150},
	{"text": "You got an A+ in a course. Take another turn.", "type": "extra_turn"},
	{"text": "You encounter a wild boar. Flee to Humanities.", "type": "go_to_jail"},
	{"text": "You sprint across campus. Advance 5 spaces.", "type": "move", "value": 5},
	{"text": "You finally start walking on the footpath. Advance 3 spaces.", "type": "move", "value": 3},
	{"text": "You accidentally paid your mess fees twice. Collect 100 refund.", "type": "collect", "value": 100},
	{"text": "Massive banking error! Swap your exact money balance with a player of your choice.", "type": "swap_money"},
	{"text": "Course review results are out. Sabotage! Pay 50 to each player.", "type": "pay_all", "value": 50},
	{"text": "Exam correction was done conservatively this semester. Collect a 25 academic bonus.", "type": "collect", "value": 25},
	{"text": "Your exam paper was not found. Move back 5 spaces in panic.", "type": "move", "value": -5},
	{"text": "Homework is due in 10 minutes and ChatGPT is down. Lose 50 in stress.", "type": "pay", "value": 50},
	{"text": "You finished your assignment 2 days early. Advance 4 spaces.", "type": "move", "value": 4},
	{"text": "You completed the exam 1 hour early. Move forward 5 spaces.", "type": "move", "value": 5},
	{"text": "You are forced to take a course you absolutely hate. Pay a 50 stress fee.", "type": "pay", "value": 50},
	{"text": "You made a meme about the professor and it went viral. Collect 200.", "type": "collect", "value": 200},
	{"text": "You find a shortcut through campus. Advance 4 spaces.", "type": "move", "value": 4},
	{"text": "Your CGPA suddenly increases after re-evaluation. Collect an academic scholarship of 150.", "type": "collect", "value": 150},
	{"text": "You attend a guest lecture that nobody else knows about. Take another turn.", "type": "extra_turn"},
	{"text": "Academic Office Error. Use this oppurtunity to steal a property.", "type": "steal_property"}
]

const fund_cards := [
	{"text": "Classes announced on Saturday. Everyone must attend Humanities. Go to Jail.", "type": "go_to_jail"},
	{"text": "Cake World promotion works in your favor. Collect 20.", "type": "collect", "value": 20},
	{"text": "Tutorial sessions begin. Pay 50 for materials.", "type": "pay", "value": 50},
	{"text": "You lack communication skills. Go to Humanities class. Do not pass GO.", "type": "go_to_jail"},
	{"text": "You slept during Humanities class. Keep this card to skip Humanities once.", "type": "out_of_jail"},
	{"text": "You attended Physics lecture. Pay 20 for notes.", "type": "pay", "value": 20},
	{"text": "Caught using ChatGPT during an exam. Go straight to Humanities.", "type": "go_to_jail"},
	{"text": "You throw a party at Tasty. Pay 30 to each player.", "type": "pay_all", "value": 30},
	{"text": "You throw a small party at Cake World. Pay 10.", "type": "pay", "value": 10},
	{"text": "Water purifier repairs are needed. Pay 100 to the institute.", "type": "pay", "value": 100},
	{"text": "You shout outside Anamudi and receive a fine. Pay 50.", "type": "pay", "value": 50},
	{"text": "Physics practicals begin. Advance to PSB.", "type": "move_to", "target": 32},
	{"text": "Your ID card is invalid. Pay a 25 replacement fee.", "type": "pay", "value": 25},
	{"text": "You lost your room keys. Pay 10.", "type": "pay", "value": 10},
	{"text": "You overate at Tasty. Pay 50 for medical bills.", "type": "pay", "value": 50},
	{"text": "Mentor meeting begins. Pay 50 for snacks.", "type": "pay", "value": 50},
	{"text": "Assignment deadline approaching. Go back 3 spaces to study.", "type": "move", "value": -3},
	{"text": "You fail a course. Go back 5 spaces.", "type": "move", "value": -5},
	{"text": "Too much coffee! Take another turn.", "type": "extra_turn"},
	{"text": "Mess food was extremely oily today. Pay 30 for antacids.", "type": "pay", "value": 30},
	{"text": "Holi celebration funds! Collect 20 from each player.", "type": "collect_all", "value": 20},
	{"text": "Preparation for Freshers' event. Pay 200 contribution.", "type": "pay", "value": 200},
	{"text": "Institute builds a new main gate. Pay 100 campus development charge.", "type": "pay", "value": 100},
	{"text": "Institute invests in a faculty lounge. Contribute 50 to the fund.", "type": "pay", "value": 50},
	{"text": "Your CGPA drops after a tough semester. Pay a 75 stress penalty.", "type": "pay", "value": 75},
	{"text": "Scholarship announcement! Collect 150 from the bank.", "type": "collect", "value": 150},
	{"text": "Lab equipment breaks during your experiment. Pay 100 repair charges.", "type": "pay", "value": 100},
	{"text": "You volunteered at a campus event. Receive a 50 reward.", "type": "collect", "value": 50},
	{"text": "The mess introduces a special dinner. Collect 30", "type": "collect", "value": 30},
	{"text": "Rawaaz preperations begin. Pay 100.", "type": "pay", "value": 100}
]

#endregion

#FUnction called in Game Controller
func setup(game_controller_ref: Node3D):
	gc = game_controller_ref

#function for handling game_state,card draw,type
func handle_draw_card(player, is_chance):
	gc.game_state = gc.GameState.TURN_ACTIONS
	var card_list = chance_cards if is_chance else fund_cards
	var card_data = card_list.pick_random()
	gc.ui.show_drawn_card(card_data, is_chance)
	await gc.ui.card_accepted 
	match card_data["type"]:
		"negative_dice":
			player.negative_dice = true
			gc.show_default_actions()
			
		"swap_money":
			gc.ui.show_target_selector(gc.players, gc.current_player, "Select a player to swap bank balances with:")
			var target_idx = await gc.ui.target_selected
			_execute_money_swap(gc.players[gc.current_player], gc.players[target_idx])
		"swap_property":
					_start_property_swap()
					return

		"steal_property":
			_start_property_steal()
			return
			
		"collect":
			player.money += card_data["value"]
			gc.ui.update_ui()
			gc.show_default_actions()
			
		"pay":
			player.money -= card_data["value"]
			gc.library_reward += card_data["value"]
			gc.ui.update_ui()
			gc.check_liquidation(player)
			
		"collect_all":
			var total_collected = 0
			for p in gc.players:
				if p != player and not p.is_bankrupt:
					p.money -= card_data["value"]
					total_collected += card_data["value"]
			player.money += total_collected
			gc.ui.update_ui()
			gc.show_default_actions()
			
		"pay_all":
			var total_paid = 0
			for p in gc.players:
				if p != player and not p.is_bankrupt:
					p.money += card_data["value"]
					total_paid += card_data["value"]
			player.money -= total_paid
			gc.ui.update_ui()
			gc.check_liquidation(player)
			
		"move":
			await player.move_steps(card_data["value"], gc.tiles)
			gc.resolve_tile(player) 
			
		"move_to":
			var target_idx = int(card_data["target"])
			if target_idx < player.current_tile and target_idx != 10:
				print(player.player_name, " passed GO! Collecting 200.")
				player.money += 200
				gc.ui.update_ui()
			
			player.current_tile = target_idx
			player.global_position = gc.tiles[target_idx].global_position + Vector3(0, 0.1, 0)
			player.next_rent_free = card_data.get("rent_free", false) 
			gc.resolve_tile(player)
			
		"go_to_jail":
			gc.send_to_jail(player)
			
		"out_of_jail":
			player.jail_free_cards += 1
			gc.ui.update_ui()
			gc.show_default_actions()
			
		"extra_turn":
			gc.rolled_doubles = true 
			gc.show_default_actions()
			
		"skip_turn":
			player.skip_turn = true
			gc.show_default_actions()
			
		"skip_other_turn":
			gc.ui.show_target_selector(gc.players, gc.current_player, "Select a player who will skip a turn:")
			var target_idx = await gc.ui.target_selected
			_execute_skip_turn(gc.players[target_idx])
		_: 
			gc.show_default_actions()

#money swap function
func _execute_money_swap(p1, p2):
	var temp_money = p1.money
	p1.money = p2.money
	p2.money = temp_money
	gc.ui.update_ui()
	gc.show_default_actions()

func _execute_skip_turn(player):
	player.skip_turn = true
	gc.show_default_actions()

#highlights properties for SWAP_STATE
func _update_swap_highlights():
	var player = gc.players[gc.current_player]
	for t in gc.tiles:
		t.set_highlight(false)
		if not t.tile_type in [BoardData.TileType.PROPERTY, BoardData.TileType.UTILITY, BoardData.TileType.CAFE]:
			continue

		if t.tile_owner == player:
			if gc.game_state == gc.GameState.SWAP_PROPERTIES:
				var has_buildings = false
				var tile_color = t.tile_data.get("color")
				
				for other_t in gc.tiles:
					if other_t.tile_type == BoardData.TileType.PROPERTY and other_t.tile_data.get("color") == tile_color:
						if other_t.funding > 0:
							has_buildings = true
							break
				
				if not has_buildings:
					if t == gc.selected_own_tile:
						t.set_highlight(true, Color.YELLOW)
					else:
						t.set_highlight(true, Color.GREEN)
		else:
			var t_color = t.tile_data.get("color", "")
			if t.tile_owner == null or not board_state.has_monopoly(t.tile_owner, t_color):
				if t == gc.selected_target_tile:
					t.set_highlight(true, Color.MAGENTA) 
				else:
					t.set_highlight(true, Color.RED)

#completes SWAP/STEAL STATE
func complete_action():
	var player = gc.players[gc.current_player]
	if gc.game_state == gc.GameState.SWAP_PROPERTIES:
		var my_tile = gc.selected_own_tile
		var target_tile = gc.selected_target_tile
		var victim = target_tile.tile_owner
		
		player.properties.erase(my_tile)
		if victim != null:
			victim.properties.erase(target_tile)
			
		my_tile.tile_owner = victim
		target_tile.tile_owner = player
		
		if victim != null:
			victim.properties.append(my_tile)
		player.properties.append(target_tile)
		
		my_tile.refresh_buildings()
		target_tile.refresh_buildings()
			
	elif gc.game_state == gc.GameState.STEAL_PROPERTY:
		var target_tile = gc.selected_target_tile
		var victim = target_tile.tile_owner
		
		if victim != null:
			victim.properties.erase(target_tile)
			
		target_tile.tile_owner = player
		player.properties.append(target_tile)
		
		target_tile.refresh_buildings()

	for t in gc.tiles: 
		t.set_highlight(false)
		
	gc.ui.hide_instruction()
	gc.ui.update_ui()
	gc.show_default_actions()
	gc.game_state = gc.GameState.TURN_ACTIONS

#setup for swap state
func _start_property_swap():
	var player = gc.players[gc.current_player]
	camera.enable_tabletop_pan(gc.players[gc.current_player].global_position)
	if player.properties.size() == 0:
		print("You have no properties to swap.")
		gc.show_default_actions()
		return
		
	var has_valid_targets = false
	for t in gc.tiles:
		if t.tile_type in [BoardData.TileType.PROPERTY, BoardData.TileType.UTILITY, BoardData.TileType.CAFE]:
			if t.tile_owner != player:
				if t.tile_owner != null and board_state.has_monopoly(t.tile_owner, t.tile_data.color):
					continue 
				has_valid_targets = true
				break
				
	if not has_valid_targets:
		print("No valid targets to swap with.")
		gc.show_default_actions()
		return

	gc.game_state = gc.GameState.SWAP_PROPERTIES
	gc.selected_own_tile = null
	gc.selected_target_tile = null
	gc.ui.show_instruction("Select 1 of your properties and 1 target property.")
	_update_swap_highlights()

#setup for steal state
func _start_property_steal():
	gc.game_state = gc.GameState.STEAL_PROPERTY
	camera.enable_tabletop_pan(gc.players[gc.current_player].global_position)
	gc.selected_own_tile = null
	gc.selected_target_tile = null
	gc.ui.show_instruction("Select a property to steal!")
	_update_swap_highlights()
