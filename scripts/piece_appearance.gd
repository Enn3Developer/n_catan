class_name CatanAppearance
extends RefCounted
## A player's hand-built look for roads, settlements and cities. Every field packs
## into one byte (colors into three), so any byte string decodes to a valid look.
## The host re-encodes whatever a client sends and never trusts it further.

const VERSION=1
const GROUPS=[["homes","Homes"],["roofs","Roofs"],["town","Town"],["city","City"],["roads","Roads"],["colors","Colors"]]
# Kinds: range [min,max] quantized to 256 steps, count [min,max] integers,
# choice [options], toggle, color.
const FIELDS=[
	{"key":"house_width","group":"homes","label":"House width","kind":"range","min":.8,"max":1.25,"default":1.0},
	{"key":"house_depth","group":"homes","label":"House depth","kind":"range","min":.8,"max":1.25,"default":1.0},
	{"key":"stories","group":"homes","label":"Stories","kind":"count","min":1,"max":3,"default":1},
	{"key":"story_height","group":"homes","label":"Story height","kind":"range","min":.8,"max":1.3,"default":1.0},
	{"key":"foundation","group":"homes","label":"Foundation","kind":"choice","options":["Stone plinth","Stilts","Timber deck","On the ground"],"default":0},
	{"key":"foundation_height","group":"homes","label":"Foundation height","kind":"range","min":0.0,"max":1.0,"default":.3},
	{"key":"wall_material","group":"homes","label":"Walls","kind":"choice","options":["Plaster","Stone","Brick","Planks","Logs"],"default":0},
	{"key":"framing","group":"homes","label":"Timber framing","kind":"choice","options":["No framing","Posts","Braced","Crossed"],"default":2},
	{"key":"windows","group":"homes","label":"Windows per wall","kind":"count","min":0,"max":3,"default":1},
	{"key":"window_shape","group":"homes","label":"Window shape","kind":"choice","options":["Square","Arched","Round","Tall"],"default":0},
	{"key":"shutters","group":"homes","label":"Shutters","kind":"toggle","default":true},
	{"key":"flower_boxes","group":"homes","label":"Flower boxes","kind":"toggle","default":false},
	{"key":"door_style","group":"homes","label":"Door","kind":"choice","options":["Plank","Arched","Double","Round"],"default":0},
	{"key":"chimneys","group":"homes","label":"Chimneys","kind":"count","min":0,"max":2,"default":1},
	{"key":"dormers","group":"homes","label":"Dormers","kind":"count","min":0,"max":2,"default":0},
	{"key":"wobble","group":"homes","label":"Hand-built wobble","kind":"range","min":0.0,"max":1.0,"default":.25},
	{"key":"variety","group":"homes","label":"Variety between houses","kind":"range","min":0.0,"max":1.0,"default":.4},
	{"key":"seed","group":"homes","label":"Variation seed","kind":"count","min":0,"max":255,"default":7},
	{"key":"roof_style","group":"roofs","label":"Roof shape","kind":"choice","options":["Gable","Hipped","Half-hipped","Mansard","Saltbox","Flat"],"default":0},
	{"key":"roof_material","group":"roofs","label":"Roofing","kind":"choice","options":["Clay tiles","Wood shingles","Slate","Thatch","Leaves"],"default":0},
	{"key":"roof_pitch","group":"roofs","label":"Roof pitch","kind":"range","min":20.0,"max":60.0,"default":42.0},
	{"key":"roof_overhang","group":"roofs","label":"Eaves overhang","kind":"range","min":0.0,"max":1.0,"default":.4},
	{"key":"ridge_cap","group":"roofs","label":"Ridge cap","kind":"toggle","default":true},
	{"key":"square","group":"town","label":"Town square","kind":"choice","options":["Cobbles","Flagstones","Grass","Sand","Planks"],"default":0},
	{"key":"centerpiece","group":"town","label":"Centerpiece","kind":"choice","options":["Well","Fountain","Tree","Statue","Bonfire","Market stall"],"default":0},
	{"key":"lanterns","group":"town","label":"Lanterns","kind":"count","min":0,"max":4,"default":2},
	{"key":"border","group":"town","label":"Town edge","kind":"choice","options":["Open","Picket fence","Hedge","Low stone wall"],"default":0},
	{"key":"banner_shape","group":"town","label":"Banner","kind":"choice","options":["Pennant","Swallowtail","Square flag","Hanging banner"],"default":0},
	{"key":"emblem","group":"town","label":"Emblem","kind":"choice","options":["Plain","Stripe","Cross","Disc","Chevron","Quartered"],"default":1},
	{"key":"pole_height","group":"town","label":"Flagpole height","kind":"range","min":.6,"max":1.6,"default":1.0},
	{"key":"city_wall","group":"city","label":"City wall","kind":"choice","options":["Stone curtain","Timber palisade","Hedge rampart","No wall"],"default":0},
	{"key":"wall_height","group":"city","label":"Wall height","kind":"range","min":.5,"max":1.5,"default":1.0},
	{"key":"crenels","group":"city","label":"Battlements","kind":"toggle","default":true},
	{"key":"towers","group":"city","label":"Towers","kind":"count","min":0,"max":6,"default":3},
	{"key":"tower_roof","group":"city","label":"Tower tops","kind":"choice","options":["Cone","Battlements","Dome","Flat"],"default":0},
	{"key":"tower_height","group":"city","label":"Tower height","kind":"range","min":.6,"max":1.6,"default":1.0},
	{"key":"keep","group":"city","label":"Landmark","kind":"choice","options":["Round tower","Square keep","Great hall","Lighthouse","Windmill","Great tree"],"default":0},
	{"key":"keep_height","group":"city","label":"Landmark height","kind":"range","min":.6,"max":1.5,"default":1.0},
	{"key":"road_surface","group":"roads","label":"Road surface","kind":"choice","options":["Planks","Cobbles","Flagstones","Dirt","Gravel"],"default":0},
	{"key":"road_width","group":"roads","label":"Road width","kind":"range","min":.6,"max":1.4,"default":1.0},
	{"key":"road_edges","group":"roads","label":"Road edges","kind":"choice","options":["No edging","Curbs","Fence","Hedge","Posts and rope"],"default":0},
	{"key":"road_lamps","group":"roads","label":"Road lamps","kind":"toggle","default":false},
	{"key":"wall_color","group":"colors","label":"Walls","kind":"color","default":"e9dcc0"},
	{"key":"roof_color","group":"colors","label":"Roof","kind":"color","default":"d9714e"},
	{"key":"trim_color","group":"colors","label":"Timber and trim","kind":"color","default":"6b4a32"},
	{"key":"stone_color","group":"colors","label":"Stonework","kind":"color","default":"9a938a"},
	{"key":"accent_color","group":"colors","label":"Doors and shutters","kind":"color","default":"4f7ea0"},
	{"key":"road_color","group":"colors","label":"Road","kind":"color","default":"c7a57a"},
	{"key":"ground_color","group":"colors","label":"Town square","kind":"color","default":"c9b99a"},
	{"key":"foliage_color","group":"colors","label":"Plants","kind":"color","default":"6f9a55"},
	{"key":"emblem_color","group":"colors","label":"Emblem","kind":"color","default":"f3ead8"}]

const PRESETS=[
	{"name":"Voyager","description":"Timber framing, clay tiles and a village well. A classic island expedition.","values":{}},
	{"name":"Harbor","description":"Stilt houses, plank roads and a lighthouse. Built for life beside the sea.",
		"values":{"foundation":1,"foundation_height":.75,"wall_material":3,"framing":0,"window_shape":2,"shutters":false,"door_style":0,"chimneys":0,"roof_style":0,"roof_material":2,"roof_pitch":34.0,"roof_overhang":.7,"square":4,"centerpiece":5,"lanterns":3,"banner_shape":1,"emblem":3,"city_wall":1,"wall_height":.7,"crenels":false,"towers":2,"tower_roof":3,"keep":3,"keep_height":1.3,"road_surface":0,"road_edges":4,"road_lamps":true,
		"wall_color":"8fa7b3","roof_color":"50606e","trim_color":"ece6d6","stone_color":"8c8a82","accent_color":"d0643f","road_color":"a88862","ground_color":"b89c78","emblem_color":"ece6d6"}},
	{"name":"Citadel","description":"Carved stone, battlements and a square keep. An island stronghold.",
		"values":{"house_depth":1.1,"stories":2,"story_height":.9,"foundation":0,"foundation_height":.5,"wall_material":1,"framing":0,"window_shape":1,"shutters":false,"door_style":1,"chimneys":1,"roof_style":1,"roof_material":2,"roof_pitch":30.0,"roof_overhang":.15,"ridge_cap":false,"square":1,"centerpiece":3,"lanterns":4,"border":3,"banner_shape":3,"emblem":2,"city_wall":0,"wall_height":1.4,"towers":6,"tower_roof":1,"tower_height":1.2,"keep":1,"keep_height":1.2,"road_surface":1,"road_edges":1,
		"wall_color":"b0aa9c","roof_color":"5d6470","trim_color":"5a4a3c","stone_color":"8a867c","accent_color":"7a3b34","road_color":"9d978b","ground_color":"a8a294","emblem_color":"e8c35a"}},
	{"name":"Wildwood","description":"Log cabins, leafy roofs and a great tree. A home among the forest.",
		"values":{"house_width":.9,"house_depth":.9,"foundation":3,"wall_material":4,"framing":0,"window_shape":2,"shutters":false,"flower_boxes":true,"door_style":3,"chimneys":1,"roof_style":0,"roof_material":4,"roof_pitch":50.0,"roof_overhang":.6,"ridge_cap":false,"wobble":.6,"variety":.7,"square":2,"centerpiece":2,"lanterns":2,"border":2,"banner_shape":0,"emblem":4,"city_wall":1,"wall_height":1.1,"crenels":false,"towers":2,"tower_roof":0,"keep":5,"keep_height":1.4,"road_surface":3,"road_width":.85,"road_edges":3,
		"wall_color":"8a6040","roof_color":"6e9a4c","trim_color":"5c3f28","stone_color":"857d6c","accent_color":"b4513a","road_color":"a8835c","ground_color":"7fa060","foliage_color":"5c8c45","emblem_color":"f0e2bd"}}]

static func field(key: String) -> Dictionary:
	for entry in FIELDS:
		if entry.key==key:return entry
	return {}

static func defaults() -> Dictionary:
	var values={}
	for entry in FIELDS:values[entry.key]=entry.default
	return values

static func preset(index: int) -> Dictionary:
	var values=defaults()
	values.merge(PRESETS[clampi(index,0,PRESETS.size()-1)].values,true)
	return values

## Packs a look. Unknown keys are ignored and missing ones take their defaults.
static func encode(values: Dictionary) -> PackedByteArray:
	var bytes=PackedByteArray([VERSION])
	for entry in FIELDS:
		var value=values.get(entry.key,entry.default)
		match entry.kind:
			"range":bytes.append(roundi(inverse_lerp(entry.min,entry.max,clampf(float(value),entry.min,entry.max))*255))
			"count":bytes.append(clampi(int(value),entry.min,entry.max)-entry.min)
			"choice":bytes.append(clampi(int(value),0,entry.options.size()-1))
			"toggle":bytes.append(1 if value else 0)
			"color":
				var color=Color(str(value)) if Color.html_is_valid(str(value)) else Color(entry.default)
				bytes.append(color.r8);bytes.append(color.g8);bytes.append(color.b8)
	return bytes

## Unpacks a look. Malformed or foreign data yields the default look.
static func decode(bytes: PackedByteArray) -> Dictionary:
	var values=defaults()
	if bytes.size()!=byte_size() or bytes[0]!=VERSION:return values
	var at=1
	for entry in FIELDS:
		match entry.kind:
			"range":values[entry.key]=lerpf(entry.min,entry.max,bytes[at]/255.0)
			"count":values[entry.key]=mini(entry.min+bytes[at],entry.max)
			"choice":values[entry.key]=mini(bytes[at],entry.options.size()-1)
			"toggle":values[entry.key]=bytes[at]!=0
			"color":
				values[entry.key]=Color8(bytes[at],bytes[at+1],bytes[at+2]).to_html(false)
				at+=2
		at+=1
	return values

static func byte_size() -> int:
	var size=1
	for entry in FIELDS:size+=3 if entry.kind=="color" else 1
	return size

static func sanitize(bytes: PackedByteArray) -> PackedByteArray:
	return encode(decode(bytes))

static func default_bytes() -> PackedByteArray:
	return encode(defaults())

static func from_hex(text: String) -> PackedByteArray:
	return sanitize(text.hex_decode()) if text.length()==byte_size()*2 else default_bytes()

## The preset this look matches exactly, or -1 once the player has changed anything.
static func preset_of(bytes: PackedByteArray) -> int:
	var packed=sanitize(bytes)
	for i in PRESETS.size():
		var candidate=preset(i)
		candidate.seed=decode(packed).seed
		if encode(candidate)==packed:return i
	return -1

## A coherent random look: one base hue drives walls, roof and trim so the result
## reads as a single place rather than noise.
static func random(rng: RandomNumberGenerator) -> Dictionary:
	var values={}
	for entry in FIELDS:
		match entry.kind:
			"range":values[entry.key]=rng.randf_range(entry.min,entry.max)
			"count":values[entry.key]=rng.randi_range(entry.min,entry.max)
			"choice":values[entry.key]=rng.randi_range(0,entry.options.size()-1)
			"toggle":values[entry.key]=rng.randf()<.5
	values.wobble=rng.randf_range(0,.6)
	values.windows=rng.randi_range(1,3)
	var hue=rng.randf()
	var roof_hue=fposmod(hue+rng.randf_range(.35,.65),1.0)
	values.wall_color=Color.from_hsv(hue,rng.randf_range(.08,.3),rng.randf_range(.72,.92)).to_html(false)
	values.roof_color=Color.from_hsv(roof_hue,rng.randf_range(.35,.65),rng.randf_range(.45,.8)).to_html(false)
	values.trim_color=Color.from_hsv(rng.randf_range(.05,.1),rng.randf_range(.35,.55),rng.randf_range(.3,.5)).to_html(false)
	values.stone_color=Color.from_hsv(rng.randf_range(.08,.15),rng.randf_range(.05,.15),rng.randf_range(.5,.7)).to_html(false)
	values.accent_color=Color.from_hsv(fposmod(roof_hue+.5,1.0),rng.randf_range(.4,.7),rng.randf_range(.45,.75)).to_html(false)
	values.road_color=Color.from_hsv(rng.randf_range(.06,.12),rng.randf_range(.2,.45),rng.randf_range(.5,.78)).to_html(false)
	values.ground_color=Color.from_hsv(rng.randf_range(.07,.3),rng.randf_range(.15,.4),rng.randf_range(.55,.8)).to_html(false)
	values.foliage_color=Color.from_hsv(rng.randf_range(.22,.36),rng.randf_range(.35,.6),rng.randf_range(.4,.65)).to_html(false)
	values.emblem_color=Color.from_hsv(rng.randf(),rng.randf_range(0,.5),rng.randf_range(.8,1)).to_html(false)
	return values
