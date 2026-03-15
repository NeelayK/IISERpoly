
# Board Data
# Does not Contain Functions


#region Constants

extends Node

enum TileType {
	CORNER,
	PROPERTY,
	CAFE,
	UTILITY,
	CHANCE,
	PROJECT_FUNDS,
	FEES
}

const COLOR_BROWN = Color("#8B5A3C") 
const COLOR_LIGHT_BLUE = Color("#9FD6E5")
const COLOR_PINK = Color("#E68AAE")  
const COLOR_ORANGE = Color("#F2A65A")     
const COLOR_RED = Color("#D95757")     
const COLOR_YELLOW = Color("#E6C85C")  
const COLOR_GREEN = Color("#5FAF7A")    
const COLOR_DARK_BLUE = Color("#3B4F8A") 
const COLOR_DEFAULT = Color("#F3EAD7")     

const PROPERTY_COLORS = {
	"Brown": COLOR_BROWN,
	"Light Blue": COLOR_LIGHT_BLUE,
	"Pink": COLOR_PINK,
	"Orange": COLOR_ORANGE,
	"Red": COLOR_RED,
	"Yellow": COLOR_YELLOW,
	"Green": COLOR_GREEN,
	"Dark Blue": COLOR_DARK_BLUE
}

#ICON PATH CONSTANTS
const ICON_DEFAULT = "res://assets/tiles/CHA.png"
const ICON_CHANCE = "res://assets/tiles/CHA.png"
const ICON_CHEST = "res://assets/tiles/FUN.png"
const ICON_TAX = "res://assets/tiles/FEE.png"
const ICON_CAFE = "res://assets/tiles/CAF.png"
const ICON_CCC ="res://assets/tiles/CCC.png"
const ICON_FACULTY = "res://assets/tiles/FAC.png"
const ICON_GO = "res://assets/tiles/STA.png"
const ICON_HUMANITIES = "res://assets/tiles/HUM.png"
const ICON_LIBRARY = "res://assets/tiles/LIB.png"
const ICON_GO_TO = "res://assets/tiles/GTH.png"

#endregion

#data for tiles: includes name,type,icon,price,color,rent,mortgage,
const TILES : Array[Dictionary] = [

	# --- SIDE 1 ---
	{"name":"GO","type":TileType.CORNER,"icon":ICON_GO},

	{"name":"Directors Residence","type":TileType.PROPERTY,
	"price":60,"color":"Brown",
	"rent":[2,10,30,90,160,250],
	"mortgage":30},

	{"name":"Project Funds","type":TileType.PROJECT_FUNDS,"icon":ICON_CHEST},

	{"name":"EESB","type":TileType.PROPERTY,
	"price":60,"color":"Brown",
	"rent":[4,20,60,180,320,450],
	"mortgage":30},

	{"name":"Semester Fee","type":TileType.FEES,"price":200,"icon":ICON_TAX},

	{"name":"Tasty","type":TileType.CAFE,
	"price":200,
	"rent":[25,50,100,200],
	"mortgage":100,
	"icon":ICON_CAFE},

	{"name":"Tennis Court","type":TileType.PROPERTY,
	"price":100,"color":"Light Blue",
	"rent":[6,30,90,270,400,550],
	"mortgage":50},

	{"name":"Chance","type":TileType.CHANCE,"icon":ICON_CHANCE},

	{"name":"Volleyball Court","type":TileType.PROPERTY,
	"price":100,"color":"Light Blue",
	"rent":[6,30,90,270,400,550],
	"mortgage":50},

	{"name":"KhoKho Court","type":TileType.PROPERTY,
	"price":120,"color":"Light Blue",
	"rent":[8,40,100,300,450,600],
	"mortgage":60},

	# --- SIDE 2 ---
	{"name":"Humanities","type":TileType.CORNER,"icon":ICON_HUMANITIES},

	{"name":"Indoor Stadium","type":TileType.PROPERTY,
	"price":140,"color":"Pink",
	"rent":[10,50,150,450,625,750],
	"mortgage":70},

	{"name":"CCC","type":TileType.UTILITY,
	"price":150,
	"mortgage":75,
	"icon":ICON_CCC},

	{"name":"GYM","type":TileType.PROPERTY,
	"price":140,"color":"Pink",
	"rent":[10,50,150,450,625,750],
	"mortgage":70},

	{"name":"Basketball Court","type":TileType.PROPERTY,
	"price":160,"color":"Pink",
	"rent":[12,60,180,500,700,900],
	"mortgage":80},

	{"name":"J-Cafe","type":TileType.CAFE,
	"price":200,
	"rent":[25,50,100,200],
	"mortgage":100,
	"icon":ICON_CAFE},

	{"name":"B Block","type":TileType.PROPERTY,
	"price":180,"color":"Orange",
	"rent":[14,70,200,550,750,950],
	"mortgage":90},

	{"name":"Project Funds","type":TileType.PROJECT_FUNDS,"icon":ICON_CHEST},

	{"name":"CDH 2","type":TileType.PROPERTY,
	"price":180,"color":"Orange",
	"rent":[14,70,200,550,750,950],
	"mortgage":90},

	{"name":"A Block","type":TileType.PROPERTY,
	"price":200,"color":"Orange",
	"rent":[16,80,220,600,800,1000],
	"mortgage":100},

	# --- SIDE 3 ---
	{"name":"Library","type":TileType.CORNER,"icon":ICON_LIBRARY},

	{"name":"C Block","type":TileType.PROPERTY,
	"price":220,"color":"Red",
	"rent":[18,90,250,700,875,1050],
	"mortgage":110},

	{"name":"Chance","type":TileType.CHANCE,"icon":ICON_CHANCE},

	{"name":"D Block","type":TileType.PROPERTY,
	"price":220,"color":"Red",
	"rent":[18,90,250,700,875,1050],
	"mortgage":110},

	{"name":"E Block","type":TileType.PROPERTY,
	"price":240,"color":"Red",
	"rent":[20,100,300,750,925,1100],
	"mortgage":120},

	{"name":"I-Cafe","type":TileType.CAFE,
	"price":200,
	"rent":[25,50,100,200],
	"mortgage":100,
	"icon":ICON_CAFE},

	{"name":"CDH 3","type":TileType.PROPERTY,
	"price":260,"color":"Yellow",
	"rent":[22,110,330,800,975,1150],
	"mortgage":130},

	{"name":"LHC","type":TileType.PROPERTY,
	"price":260,"color":"Yellow",
	"rent":[22,110,330,800,975,1150],
	"mortgage":130},

	{"name":"Faculty Lounge","type":TileType.UTILITY,
	"price":150,
	"mortgage":75,
	"icon":ICON_FACULTY},

	{"name":"CDH 1","type":TileType.PROPERTY,
	"price":280,"color":"Yellow",
	"rent":[24,120,360,850,1025,1200],
	"mortgage":140},

	# --- SIDE 4 ---
	{"name":"Go To Humanities","type":TileType.CORNER,"icon":ICON_GO_TO},

	{"name":"MSB","type":TileType.PROPERTY,
	"price":300,"color":"Green",
	"rent":[26,130,390,900,1100,1275],
	"mortgage":150},

	{"name":"PSB","type":TileType.PROPERTY,
	"price":300,"color":"Green",
	"rent":[26,130,390,900,1100,1275],
	"mortgage":150},

	{"name":"Project Funds","type":TileType.PROJECT_FUNDS,"icon":ICON_CHEST},

	{"name":"CSB","type":TileType.PROPERTY,
	"price":320,"color":"Green",
	"rent":[28,150,450,1000,1200,1400],
	"mortgage":160},

	{"name":"Cake World","type":TileType.CAFE,
	"price":200,
	"rent":[25,50,100,200],
	"mortgage":100,
	"icon":ICON_CAFE},

	{"name":"Chance","type":TileType.CHANCE,"icon":ICON_CHANCE},

	{"name":"BSB","type":TileType.PROPERTY,
	"price":350,"color":"Dark Blue",
	"rent":[35,175,500,1100,1300,1500],
	"mortgage":175},

	{"name":"Mess Fees","type":TileType.FEES,"price":100,"icon":ICON_TAX},

	{"name":"CIF","type":TileType.PROPERTY,
	"price":400,"color":"Dark Blue",
	"rent":[50,200,600,1400,1700,2000],
	"mortgage":200}
]
#House (funds cost)
const property_rules := {

	"Brown": {"investment": 50},
	"Light Blue": {"investment": 50},
	"Pink": {"investment": 100},
	"Orange": {"investment": 100},
	"Red": {"investment": 150},
	"Yellow": {"investment": 150},
	"Green": {"investment": 200},
	"Dark Blue": {"investment": 200}
}

#Cafe charge
var cafe_charge = {
	1: 25,
	2: 50,
	3: 100,
	4: 200
}
#utility multipler
var utility_rules = {
	one_owned_multiplier = 4,
	two_owned_multiplier = 10
}
