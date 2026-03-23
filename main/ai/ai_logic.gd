# ai_brain.gd
extends Node
class_name AIBrain

@onready var me = get_parent()

func decide_auction_bid(property_data: Dictionary, current_bid: int) -> int:
    var max_willing_to_pay = property_data["price"]
    var my_safe_money = me.money - 100
    
    if current_bid < max_willing_to_pay and current_bid < my_safe_money:
        return current_bid + 10
    else:
        return 0

func choose_target_player(all_players: Array, action_type: String) -> int:
    var best_target_idx = 0
    var highest_value = -99999
    var lowest_value = 99999
    
    for i in range(all_players.size()):
        var p = all_players[i]
        if p == me or p.is_bankrupt: continue
        
        match action_type:
            "swap_money":
                if p.money > highest_value:
                    highest_value = p.money
                    best_target_idx = i
                    
            "skip_other_turn":
                best_target_idx = i 
                
    return best_target_idx

func get_board_state(tiles: Array) -> Array:
    var state = []
    for tile in tiles:
        if tile.tile_type == BoardData.TileType.PROPERTY or tile.tile_type == BoardData.TileType.CAFE or tile.tile_type == BoardData.TileType.UTILITY:
            var is_mine = 1.0 if tile.tile_owner == me else 0.0
            var is_enemy = 1.0 if (tile.tile_owner != null and tile.tile_owner != me) else 0.0
            var is_mortgaged = 1.0 if tile.is_mortgaged else 0.0
            var fund_level = tile.funding / 5.0
            
            state.append_array([is_mine, is_enemy, is_mortgaged, fund_level])
    return state
    
func choose_swap_pair(my_properties: Array, all_tiles: Array) -> Array:
    my_properties.sort_custom(func(a, b): return a.tile_data["price"] < b.tile_data["price"])
    var my_worst = my_properties[0]
    
    var best_target = null
    var highest_price = -1
    
    for t in all_tiles:
        if not t.tile_type in [BoardData.TileType.PROPERTY, BoardData.TileType.UTILITY, BoardData.TileType.CAFE]:
            continue
        if t.tile_owner != null and t.tile_owner != me:
            if t.tile_data.has("color") and me.get_parent().board_state.has_monopoly(t.tile_owner, t.tile_data.color):
                continue
                
            if t.tile_data["price"] > highest_price:
                highest_price = t.tile_data["price"]
                best_target = t
                
    return [my_worst, best_target]

func choose_steal_target(all_tiles: Array):
    var best_target = null
    var highest_price = -1
    
    for t in all_tiles:
        if not t.tile_type in [BoardData.TileType.PROPERTY, BoardData.TileType.UTILITY, BoardData.TileType.CAFE]:
            continue
        if t.tile_owner != null and t.tile_owner != me:
            if t.tile_data["price"] > highest_price:
                highest_price = t.tile_data["price"]
                best_target = t
    return best_target

func decide_jail_action(can_pay: bool, has_card: bool) -> String:
    return "roll"

func decide_buy_property(tile: Node, price: int, my_money: int) -> bool:
    if my_money >= price:
        return true
    return false
    
func choose_turn_action(state: Array, action_space: Dictionary) -> Dictionary:
    # action_space contains keys like "end_turn", "build", "mortgage", etc.
    # The values are arrays of the specific tiles those actions can be performed on.
    
    # TODO: Pass this state and action_space to the RL model in the future.
    
    # For this current random test, we ignore the building/mortgaging options 
    # to prevent the untrained AI from getting stuck in an infinite loop of 
    # building and selling the same property on the same turn.
    return {
        "action": "end_turn",
        "tile": null
    }

func choose_liquidation_action(state: Array, action_space: Dictionary) -> Dictionary:
    # When money < 0. action_space contains "declare_bankruptcy", "sell", "mortgage".
    
    # TODO: Pass this to the RL model in the future.
    
    # For the random test, the AI just accepts defeat so the game doesn't crash.
    return {
        "action": "declare_bankruptcy",
        "tile": null
    }
