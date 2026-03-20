extends CanvasLayer

signal card_accepted
signal player_hovered(player_index)
signal target_selected(index: int)
signal player_unhovered
signal trade_cancelled
signal trade_accepted
signal trade_started(player)

@export var player_panel_scene : PackedScene
@export var button_scene : PackedScene
@export var CardPanel : Control

@onready var turn_display_label = $TurnDisplay/Name
@onready var target_menu = $VictimPanel/VictimSelectionMenu
@onready var panel_list = $PlayerPanels/PanelList
@onready var action_container = $ActionBar/ActionButtons
@onready var detail_panel = $PropertyDetailPanel
@onready var rent_list = $PropertyDetailPanel/RentList
@onready var auction_panel = $AuctionPanel
@onready var auction_property_name = $AuctionPanel/VBoxContainer/PropertyName
@onready var auction_current_bid = $AuctionPanel/VBoxContainer/CurrentBid
@onready var auction_highest_bidder = $AuctionPanel/VBoxContainer/HighestBidder
@onready var bidding_player_label = $AuctionPanel/VBoxContainer/BiddingPlayerLabel
@onready var bid_slider = $AuctionPanel/VBoxContainer/BidSlider
@onready var bid_value_label = $AuctionPanel/VBoxContainer/BidValueLabel
@onready var bid_button = $AuctionPanel/VBoxContainer/AuctionButtons/BidButton
@onready var fold_button = $AuctionPanel/VBoxContainer/AuctionButtons/FoldButton
@onready var plus10 = $AuctionPanel/"VBoxContainer/QuickMoney/+10"
@onready var plus50 = $AuctionPanel/"VBoxContainer/QuickMoney/+50"
@onready var plus100 = $AuctionPanel/"VBoxContainer/QuickMoney/+100"
@onready var plus500 = $AuctionPanel/"VBoxContainer/QuickMoney/+500"
@onready var title = CardPanel.get_node("VBoxContainer/Title")
@onready var desc = CardPanel.get_node("VBoxContainer/Description")
@onready var trade_panel = $TradePanel
@onready var p1_head = $TradePanel/VBoxContainer/ScrollContainer/HBoxContainer/P1/Head
@onready var p2_head = $TradePanel/VBoxContainer/ScrollContainer/HBoxContainer/P2/Head
@onready var p1_property_list = $TradePanel/VBoxContainer/ScrollContainer/HBoxContainer/P1/PropertyList
@onready var p2_property_list = $TradePanel/VBoxContainer/ScrollContainer/HBoxContainer/P2/PropertyList
@onready var p1_total_label = $TradePanel/VBoxContainer/ScrollContainer/HBoxContainer/P1/Total
@onready var p2_total_label = $TradePanel/VBoxContainer/ScrollContainer/HBoxContainer/P2/Total
@onready var p1_cash_input = $TradePanel/VBoxContainer/ScrollContainer/HBoxContainer/P1/HSlider
@onready var p2_cash_input = $TradePanel/VBoxContainer/ScrollContainer/HBoxContainer/P2/HSlider
@onready var confirm_trade_btn = $TradePanel/VBoxContainer/Buttons/Confirm
@onready var cancel_trade_btn = $TradePanel/VBoxContainer/Buttons/Cancel
@onready var p1_cash_label = $TradePanel/VBoxContainer/ScrollContainer/HBoxContainer/P1/Cash
@onready var p2_cash_label = $TradePanel/VBoxContainer/ScrollContainer/HBoxContainer/P2/Cash
@onready var pause_menu = $PauseMenu
@onready var resume_btn = $PauseMenu/VBoxContainer/Resume
@onready var quit_btn = $PauseMenu/VBoxContainer/Quit
@onready var speed_up = $SpeedUp
@onready var pause_icon_btn = $PauseButton

var panels = []
var buttons = {}
var is_mobile:bool = false


#initial setup (bid and trade sliders)
func _ready():
	is_mobile = OS.has_feature("mobile")
	bid_slider.step = 10
	bid_slider.min_value = 0
	bid_slider.max_value = 5000
	bid_slider.value_changed.connect(_on_slider_changed)
	p1_cash_input.value_changed.connect(func(_val): update_trade_ui())
	p2_cash_input.value_changed.connect(func(_val): update_trade_ui())
	confirm_trade_btn.pressed.connect(func():trade_accepted.emit())
	cancel_trade_btn.pressed.connect(func():trade_cancelled.emit())
	pause_menu.hide()
	speed_up.pressed.connect(change_time)
	# Connect Pause Buttons
	resume_btn.pressed.connect(_on_resume_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)
	pause_icon_btn.pressed.connect(toggle_pause)

#player hud
func setup_players(players):
	for i in range(players.size()):
		var panel = player_panel_scene.instantiate()
		panel.get_node("Data/PlayerName").text = players[i].player_name
		panel.get_node("Data/Money").text = "$" + str(players[i].money)
		panel.mouse_filter = Control.MOUSE_FILTER_STOP 
		panel.mouse_entered.connect(_on_panel_mouse_entered.bind(i))
		panel.mouse_exited.connect(_on_panel_mouse_exited)
		panel_list.add_child(panel)
		panels.append({ "panel": panel, "player": players[i] })

func update_turn_display(text:String):
	turn_display_label.text = text

#updates player huds money
func update_ui():
	for entry in panels:
		var money_label = entry.panel.get_node("Data/Money")
		var player = entry.player
		
		if player.is_bankrupt:
			money_label.text = "BANKRUPT"
			money_label.add_theme_color_override("font_color", Color.RED)
			# Optional: Dim the whole panel
			entry.panel.modulate = Color(0.39, 0.519, 0.61, 0.8) 
		else:
			money_label.text = "$" + str(player.money)
			# Reset color if they aren't bankrupt (in case of game resets)
			money_label.remove_theme_color_override("font_color")
			entry.panel.modulate = Color.WHITE

#removes buttons in action container
func clear_buttons():
	for child in action_container.get_children():
		child.queue_free()
	buttons.clear()

#creates button in action container
func create_button(action_name: String, text: String, fallback_helper: String, callback: Callable):
	var btn = button_scene.instantiate()
	btn.text = text
	var helper_label = btn.get_node("HelperLabel")
	
	if is_mobile:
		helper_label.visible = false
	else:
		if InputMap.has_action(action_name):
			var events = InputMap.action_get_events(action_name)
			if events.size() > 0:
				var helper_text = events[0].as_text().get_slice(" (", 0)
				helper_label.text = helper_text.replace(" - Physical", "")
				print(helper_label.text)
				
			else:
				helper_label.text = fallback_helper
		else:
			helper_label.text = fallback_helper

	if callback.is_valid():
		btn.pressed.connect(callback)
		
	if InputMap.has_action(action_name):
		var shortcut = Shortcut.new()
		var event = InputEventAction.new()
		event.action = action_name
		shortcut.events = [event]
		btn.shortcut = shortcut 
		
	action_container.add_child(btn)
	buttons[action_name] = btn

#create roll button
func show_roll_button(callback):
	clear_buttons()
	create_button("action_roll", "Roll Dice", "Space", callback)

#create buy/acution buttons
func show_property_buttons(buy_callback: Callable, auction_callback: Callable, can_buy: bool):
	clear_buttons()
	create_button("action_buy", "Buy Property", "X", buy_callback)
	if not can_buy:
		buttons["action_buy"].disabled = true
		buttons["action_buy"].text = "Not Enough Funds"
	create_button("action_auction", "Auction", "C", auction_callback)

func show_turn_actions(callbacks: Dictionary, is_liquidation: bool = false):
	clear_buttons()
	create_button("action_build", "Invest Funds", "A", callbacks.build)
	create_button("action_sell", "Take Back Funds", "S", callbacks.sell)
	create_button("action_mortgage", "Mortgage", "Z", callbacks.mortgage)
	create_button("action_unmortgage", "Unmortgage", "C", callbacks.unmortgage)
	create_button("action_trade", "Trade", "X", callbacks.trade)
	
	var end_label = "Give Up (Bankrupt)" if is_liquidation else "End Turn"
	create_button("action_end_turn", end_label, "Space", callbacks.end_turn)

func show_jail_buttons(pay_callback, card_callback, roll_callback, can_pay, has_card):
	clear_buttons()
	create_button("action_jail_roll", "Roll for Doubles", "Space", roll_callback)
	if has_card: 
		create_button("action_jail_card", "Use Humanities Pass", "C", card_callback)
	create_button("action_jail_pay", "Pay $50 Fine", "X", pay_callback)
	if not can_pay:
		buttons["action_jail_pay"].disabled = true
		buttons["action_jail_pay"].text = "Can't Afford Fine"

#creates auction panel with functionality
func show_auction_panel(player, property, current_bid, highest_bidder, bid_callback:Callable, fold_callback:Callable):
	auction_panel.visible = true
	bidding_player_label.text = "Bidding: " + player.player_name
	auction_property_name.text = property.tile_data.name
	auction_current_bid.text = "Current Bid: $" + str(current_bid)
	auction_highest_bidder.text = "Highest Bidder: " + (highest_bidder.player_name if highest_bidder else "None")
	bid_slider.min_value = current_bid + 10
	bid_slider.max_value = player.money
	bid_slider.value = bid_slider.min_value
	bid_value_label.text = "Bid: $" + str(bid_slider.value)

	for sig in [bid_button.pressed, fold_button.pressed, plus10.pressed ,plus50.pressed, plus100.pressed, plus500.pressed]:
		for c in sig.get_connections(): sig.disconnect(c.callable)

	bid_button.pressed.connect(func(): bid_callback.call(int(bid_slider.value)))
	fold_button.pressed.connect(fold_callback)
	plus10.pressed.connect(func():_quick_bid(10))
	plus50.pressed.connect(func(): _quick_bid(50))
	plus100.pressed.connect(func(): _quick_bid(100))
	plus500.pressed.connect(func(): _quick_bid(500))
	bid_button.grab_focus()

#shows tile data
func show_property_details(tile, library_money= 0):
	detail_panel.visible = true
	$PropertyDetailPanel/Title.text = tile.tile_data.get("name", "Special Tile")
	for child in rent_list.get_children(): child.queue_free()

	if tile.tile_type in [BoardData.TileType.CHANCE, BoardData.TileType.PROJECT_FUNDS, BoardData.TileType.FEES]:
		$PropertyDetailPanel/Owner.text = ""
		
		var info_lbl = Label.new()
		info_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if tile.tile_type == BoardData.TileType.CHANCE:
			info_lbl.text = "Chance: Land here to draw a random event card."
		elif tile.tile_type == BoardData.TileType.PROJECT_FUNDS:
			info_lbl.text = "Project Funds: Land here to draw a community fund card."
		else:
			info_lbl.text = "Pay the fee shown on the board."
			
		rent_list.add_child(info_lbl)
		return

	$PropertyDetailPanel/Owner.text = "Owner: " + (tile.tile_owner.player_name if tile.tile_owner else "None")
	var rents = tile.tile_data.get("rent", [])
	var current_level = 0

	if tile.tile_type == BoardData.TileType.UTILITY:
		current_level = get_owner_count(tile)
		var lbl = Label.new()
		lbl.text = "4x roll"
		if current_level==1:
			lbl.add_theme_color_override("font_color", Color.YELLOW)
			lbl.text = ">> " + lbl.text + " <<"
		elif current_level==2:
			lbl.add_theme_color_override("font_color", Color.YELLOW)
			lbl.text = ">> " + lbl.text + " <<"
		rent_list.add_child(lbl)
		var lbl2 = Label.new()
		lbl2.text = "10x roll"
		rent_list.add_child(lbl2)
	
	elif tile.tile_type == BoardData.TileType.CORNER:
		if tile.tile_data.get("name") == "Library":
			$PropertyDetailPanel/Owner.text = tile.tile_data.get("desc", []) + "\n Current Money: $" + str(library_money)
		else:
			$PropertyDetailPanel/Owner.text = tile.tile_data.get("desc", [])
	
	elif tile.tile_type == BoardData.TileType.PROPERTY:
		current_level = tile.funding
	
	elif tile.tile_type == BoardData.TileType.CAFE:
		current_level = get_owner_count(tile)-1
	
	else:
		current_level = get_owner_count(tile)

	for i in range(rents.size()):
		var lbl = Label.new()
		lbl.text = "Level " + str(i) + ": $" + str(rents[i])
		if i == current_level:
			lbl.add_theme_color_override("font_color", Color.YELLOW)
			lbl.text = ">> " + lbl.text + " <<"
		rent_list.add_child(lbl)

#show card ui
func show_drawn_card(card_data: Dictionary, is_chance: bool):
	CardPanel.visible = true
	title.text = "CHANCE" if is_chance else "PROJECT FUNDS"
	desc.text = card_data["text"]
	CardPanel.modulate = Color(1, 0.5, 0) if is_chance else Color(0.2, 0.6, 1)

#helper functions

func _quick_bid(amount):
	if bid_slider.value + amount <= bid_slider.max_value:
		bid_slider.value += amount
func _on_slider_changed(value):
	bid_value_label.text = "Bid: $" + str(value)
func hide_auction_panel():
	auction_panel.visible = false
func get_owner_count(tile) -> int:
	if not tile.tile_owner: return 0
	var count = 0
	for p in tile.tile_owner.properties:
		if p.tile_type == tile.tile_type:
			count += 1
	return count
func _on_panel_mouse_entered(index: int):
	player_hovered.emit(index)
func _on_panel_mouse_exited():
	player_unhovered.emit()
func _on_accept_button_pressed():
	emit_signal("card_accepted")
	CardPanel.visible = false

#show victim selector for specific cards
func show_target_selector(players: Array, current_idx: int, instruction_text: String):
	$VictimPanel.visible = true
	$VictimPanel/Instructions.text = instruction_text
	
	for child in target_menu.get_children(): 
		child.queue_free()
	
	for i in range(players.size()):
		if i == current_idx or players[i].is_bankrupt: 
			continue
		
		var btn = Button.new()
		btn.text = players[i].player_name
		btn.pressed.connect(func(): 
			$VictimPanel.visible = false
			target_selected.emit(i)
		)
		target_menu.add_child(btn)

#reuse victim panel for only instructions
func show_instruction(instruction_text: String):
	$VictimPanel.visible = true
	$VictimPanel/Instructions.text = instruction_text
	for child in target_menu.get_children(): 
		child.queue_free()

#creates a new button to hide victim panel
func show_confirm_button(button_text: String, callback: Callable):
	for child in target_menu.get_children(): 
		child.queue_free()
		
	var btn = Button.new()
	btn.text = button_text
	btn.pressed.connect(func():
		$VictimPanel.visible = false
		callback.call()
	)
	target_menu.add_child(btn)

#this function hides victim and terminates children
func hide_instruction():
	$VictimPanel.visible = false
	for child in target_menu.get_children(): 
		child.queue_free()


#-------------
#trading
#--------------

func trade_selector(players: Array, current_idx: int):
	$VictimPanel.visible = true
	$VictimPanel/Instructions.text = "Select Player You Want to Trade With:"
	
	for child in target_menu.get_children(): 
		child.queue_free()
	
	for i in range(players.size()):
		if i == current_idx or players[i].is_bankrupt: 
			continue
		
		var btn = Button.new()
		btn.text = "Trade with " + players[i].player_name
		btn.pressed.connect(func(): 
			$VictimPanel.visible = false
			current_trade["p2"]=players[i]
			current_trade["p1"]=players[current_idx]
			trade_started.emit(players[i])
			
		)
		target_menu.add_child(btn)

var current_trade = {
	"p1": null,
	"p2": null,
	"p1_props": [],
	"p2_props": []
}

func open_trade_panel(player1, player2):
	current_trade.p1 = player1
	current_trade.p2 = player2
	current_trade.p1_props.clear()
	current_trade.p2_props.clear()
	p1_head.text = player1.player_name
	p2_head.text = player2.player_name
	p1_cash_input.value = 0
	p1_cash_input.max_value = player1.money
	p2_cash_input.value = 0
	p2_cash_input.max_value = player2.money
	p1_cash_input.editable = true
	p2_cash_input.editable = true
	confirm_trade_btn.text = "Propose Trade"
	cancel_trade_btn.text = "Cancel"
	$TradePanel/VBoxContainer/Head.text = "Create Trade Offer"
	trade_panel.show()
	update_trade_ui()

func toggle_trade_property(tile):
	if tile.tile_owner == current_trade.p1:
		if tile in current_trade.p1_props:
			current_trade.p1_props.erase(tile)
		else:
			current_trade.p1_props.append(tile)
			
	elif tile.tile_owner == current_trade.p2:
		if tile in current_trade.p2_props:
			current_trade.p2_props.erase(tile)
		else:
			current_trade.p2_props.append(tile)
	
	update_trade_ui()

func update_trade_ui():
	for child in p1_property_list.get_children(): child.queue_free()
	for child in p2_property_list.get_children(): child.queue_free()
	var p1_prop_value = 0
	for t in current_trade.p1_props:
		var price = t.tile_data.get("price", 0)
		p1_prop_value += price
		var lbl = Label.new()
		lbl.text = t.tile_data.get("name", "Property") + " ($" + str(price) + ")"
		p1_property_list.add_child(lbl)
		
	var p2_prop_value = 0
	for t in current_trade.p2_props:
		var price = t.tile_data.get("price", 0)
		p2_prop_value += price
		var lbl = Label.new()
		lbl.text = t.tile_data.get("name", "Property") + " ($" + str(price) + ")"
		p2_property_list.add_child(lbl)

	var p1_cash = p1_cash_input.value
	var p2_cash = p2_cash_input.value
	p1_cash_label.text = "$" + str(p1_cash)
	p2_cash_label.text = "$" + str(p2_cash)
	p1_total_label.text = "Total Value: $" + str(p1_prop_value + p1_cash)
	p2_total_label.text = "Total Value: $" + str(p2_prop_value + p2_cash)
	
	var p1_giving = current_trade.p1_props.size() > 0 or p1_cash > 0
	var p2_giving = current_trade.p2_props.size() > 0 or p2_cash > 0
	confirm_trade_btn.disabled = not (p1_giving and p2_giving)

func close_trade_panel():
	trade_panel.hide()
	
func open_trade_review():
	p1_cash_input.editable = false
	p2_cash_input.editable = false
	confirm_trade_btn.text = "Accept Trade"
	cancel_trade_btn.text = "Decline Trade"
	$TradePanel/VBoxContainer/Head.text = current_trade.p2.player_name + ": Review this offer!"
	update_trade_ui()
	
#-------------
#PauseMenu
#-------------
func toggle_pause():
	var is_paused = !get_tree().paused
	get_tree().paused = is_paused
	pause_menu.visible = is_paused
	
	if is_paused:
		resume_btn.grab_focus()

func _on_resume_pressed():
	toggle_pause()

func _on_quit_pressed():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://main/main_menu/main_menu.tscn")

func _input(event):
	if not get_tree().paused:
		if event.is_action_pressed("action_end_turn"):
			_on_accept_button_pressed()
			
func change_time():
	if Engine.time_scale == 1.5:
		Engine.time_scale = 3
		speed_up.text = "x2"
	else:
		Engine.time_scale = 1.5
		speed_up.text = "x1"
