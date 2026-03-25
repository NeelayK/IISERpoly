extends Node

var player_data = [] 
var new_scale = 1.0
var is_training = true

const COLOR_WHITE = Color("ccc8bfff") 
const COLOR_LIGHT_BLUE = Color("479ecfff")
const COLOR_PINK = Color("#E68AAE")  
const COLOR_ORANGE = Color("#F2A65A")     
const COLOR_RED = Color("#D95757")     
const COLOR_YELLOW = Color("#E6C85C")  
const COLOR_GREEN = Color("#5FAF7A")    
const COLOR_DARK_BLUE = Color("#3B4F8A") 
const COLOR_DEFAULT = Color("#F3EAD7")     

const ALLOWED_COLORS = {
	"White": COLOR_WHITE,
	"Light Blue": COLOR_LIGHT_BLUE,
	"Pink": COLOR_PINK,
	"Orange": COLOR_ORANGE,
	"Red": COLOR_RED,
	"Yellow": COLOR_YELLOW,
	"Green": COLOR_GREEN,
	"Dark Blue": COLOR_DARK_BLUE
}


var FIGURINE_MESHES = [
	{"name": "Palette", "model": preload("res://assets/players/Art.obj")},
	{"name": "Knight", "model": preload("res://assets/players/Knight.obj")},
	{"name": "Beaker", "model": preload("res://assets/players/Beaker.obj")},
	{"name": "Guitar", "model": preload("res://assets/players/Guitar.obj")},
	{"name": "Rocket", "model": preload("res://assets/players/Rocket.obj")},
	{"name": "Wolf", "model": preload("res://assets/players/Wolf.obj")}
]
