extends CanvasLayer

signal card_accepted
signal player_hovered(player_index)
signal target_selected(index: int)
signal player_unhovered

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

var panels = []
var buttons = {}

#initial setup (only slider)
func _ready():
	bid_slider.step = 10
	bid_slider.min_value = 0
	bid_slider.max_value = 5000
	bid_slider.value_changed.connect(_on_slider_changed)

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
func create_button(id:String, text:String, helper:String, callback:Callable):
	var btn = button_scene.instantiate()
	btn.text = text
	btn.get_node("HelperLabel").text = helper
	if callback.is_valid():
		btn.pressed.connect(callback)
	action_container.add_child(btn)
	buttons[id] = btn

#create roll button
func show_roll_button(callback):
	clear_buttons()
	create_button("roll", "Roll Dice", "SPACE", callback)

#create buy/acution buttons
func show_property_buttons(buy_callback: Callable, auction_callback: Callable, can_buy: bool):
	clear_buttons()
	create_button("buy", "Buy Property", "B", buy_callback)
	if not can_buy:
		buttons["buy"].disabled = true
		buttons["buy"].text = "Not Enough Funds"
	create_button("auction", "Auction", "A", auction_callback)

# create build,sell,mortgage,ungorgae,trade,end_turn buttons
func show_turn_actions(callbacks: Dictionary, is_liquidation: bool = false):
	clear_buttons()
	create_button("build", "Invest Funds", "F", callbacks.build)
	create_button("sell", "Take Back Funds", "S", callbacks.sell)
	create_button("mortgage", "Mortgage", "M", callbacks.mortgage)
	create_button("unmortgage", "Unmortgage", "U", callbacks.unmortgage)
	create_button("trade", "Trade", "T", callbacks.trade)
	var end_label = "Give Up (Bankrupt)" if is_liquidation else "End Turn"
	create_button("end_turn", end_label, "Enter", callbacks.end_turn)

#create buttons when in jail
func show_jail_buttons(pay_callback, card_callback, roll_callback, can_pay, has_card):
	clear_buttons()
	create_button("jail_roll", "Roll for Doubles", "R", roll_callback)
	if has_card: create_button("jail_card", "Use Humanities Pass", "C", card_callback)
	create_button("jail_pay", "Pay $50 Fine", "P", pay_callback)
	if not can_pay:
		buttons["jail_pay"].disabled = true
		buttons["jail_pay"].text = "Can't Afford Fine"

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
			
		rent_list.add_child(lbl)
		var lbl2 = Label.new()
		lbl2.text = "10x roll"
		if current_level==2:
			lbl.add_theme_color_override("font_color", Color.YELLOW)
			lbl.text = ">> " + lbl.text + " <<"
		rent_list.add_child(lbl2)
	
	elif tile.tile_type == BoardData.TileType.CORNER:
		if tile.tile_data.get("name") == "Library":
			$PropertyDetailPanel/Owner.text = tile.tile_data.get("desc", []) + "\n Current Money: $" + str(library_money)
		else:
			$PropertyDetailPanel/Owner.text = tile.tile_data.get("desc", [])
	
	elif tile.tile_type == BoardData.TileType.PROPERTY:
		current_level = tile.funding
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
		btn.text = "Swap with " + players[i].player_name
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
