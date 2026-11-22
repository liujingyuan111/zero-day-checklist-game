class_name NightStreet
extends Node3D

const SCALE := 32.0
const TILT := 0.83
const MAP_CENTER := Vector2(640, 360)
const VIEW_NAMES := ["南侧", "东侧", "北侧", "西侧"]
const ZOOM_STEPS := [0.55, 0.7, 0.85, 1.0, 1.2, 1.45, 1.75]
const BUILDINGS := {
	&"shelter": Rect2(96,305,180,86),
	&"booth": Rect2(503,225,108,66),
	&"pump": Rect2(926,285,187,84)
}
const HEIGHTS := {&"shelter": 2.15, &"booth": 1.75, &"pump": 2.45}
const GROUND := Color("#535d55")
const ROAD := Color("#363e3f")
var camera: Camera3D
var daylight: DirectionalLight3D
var atmosphere: Environment
var courier: Sprite3D
var lamps: Array[OmniLight3D] = []
var traces: Array[MeshInstance3D] = []
var materials := {}
var clock := 0.0
var view_index := 0
var zoom_index := 3
var yaw := 0.0
var target_yaw := 0.0
var zoom_factor := 1.0
var following := false
var ground_transform := Transform2D.IDENTITY


static func ground(at: Vector2, lift := 0.0) -> Vector3:
	return Vector3((at.x - 640.0) / SCALE, lift, (at.y - 360.0) / (SCALE * sin(TILT)))


func _ready() -> void:
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	add_child(camera)
	_place_camera(MAP_CENTER)
	atmosphere = Environment.new()
	atmosphere.background_mode = Environment.BG_COLOR
	atmosphere.background_color = Color("#34444d")
	atmosphere.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	atmosphere.ambient_light_color = Color("#c7d2bf")
	atmosphere.ambient_light_energy = 0.78
	var environment_node := WorldEnvironment.new()
	environment_node.environment = atmosphere
	add_child(environment_node)
	daylight = DirectionalLight3D.new()
	daylight.rotation_degrees = Vector3(-57,-38,0)
	daylight.light_color = Color("#ffe1b3")
	daylight.light_energy = 1.15
	daylight.shadow_enabled = true
	add_child(daylight)
	_box(Vector2(640,360),Vector2(6500,6500),0.22,GROUND,-0.23)
	_box(Vector2(640,498),Vector2(6500,110),0.03,ROAD,-0.01)
	for y in [441,554]:
		_box(Vector2(640,y),Vector2(6500,8),0.12,Color("#a39e88"))
	for x in range(-2012,3400,83):
		_box(Vector2(x,496),Vector2(36,3),0.02,Color("#b2a278"),0.025)
	for x in range(382,488,19):
		_box(Vector2(x,517),Vector2(11,57),0.02,Color("#b7b19a"),0.025)
	_building(BUILDINGS[&"shelter"],HEIGHTS[&"shelter"],Color("#777f70"),Color("#58665a"))
	_building(BUILDINGS[&"booth"],HEIGHTS[&"booth"],Color("#8c7762"),Color("#616e65"))
	_building(BUILDINGS[&"pump"],HEIGHTS[&"pump"],Color("#6d7c81"),Color("#465d65"))
	# Warm door frames, front windows and a roller shutter give each site a silhouette.
	_front(Vector2(203,392),2.05,Color("#dcae73"))
	_front(Vector2(557,292),1.45,Color("#d5ad6c"))
	_front(Vector2(1012,371),2.1,Color("#8bb4b3"))
	for x in [125,157,244]:
		_box(Vector2(x,392),Vector2(19,2),0.48,Color("#c7a66f"),0.8)
	for x in [952,1079]:
		_box(Vector2(x,371),Vector2(24,2),0.55,Color("#93afa7"),1.1)
	for x in [529,553,577]:
		_box(Vector2(x,292),Vector2(13,2),0.26,Color("#8a9d91"),0.78)
	for x in range(942,1108,17):
		_box(Vector2(x,312),Vector2(3,61),0.06,Color("#637373"),2.55)
	_box(Vector2(159,339),Vector2(56,33),0.46,Color("#728073"),2.25)
	for x in range(138,184,8):
		_box(Vector2(x,338),Vector2(3,24),0.03,Color("#465657"),2.73)
	# A separate maintenance shed also acts as a sight-line and movement obstacle.
	_building(Rect2(654,320,116,88),1.55,Color("#707169"),Color("#626b66"))
	for at in [Vector2(352,278),Vector2(836,233),Vector2(1165,416),Vector2(65,443),Vector2(842,561)]:
		_tree(at)
	for x in [199,529,846,1122]:
		_lamp(Vector2(x,447))
	for x in range(60,1250,105):
		_box(Vector2(x,571),Vector2(6,7),0.46,Color("#89918a"))
	for at in [Vector2(360,349),Vector2(795,417),Vector2(1170,291)]:
		_car(at)
	for at in [Vector2(999,398),Vector2(1018,390),Vector2(1036,394)]:
		var seam := _box(at,Vector2(6,15),0.43,Color("#87ede9"),0.05)
		seam.rotation.z = 0.35
		seam.hide()
		traces.append(seam)
	courier = Sprite3D.new()
	courier.texture = preload("res://art/first_night/courier.png")
	courier.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	courier.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	courier.pixel_size = 0.09
	courier.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	courier.centered = true
	courier.offset = Vector2(0,7.5)
	courier.shaded = false
	add_child(courier)


func _mat(color: Color) -> StandardMaterial3D:
	if not materials.has(color):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 0.97
		materials[color] = mat
	return materials[color]


func _box(center: Vector2, extent: Vector2, height: float, color: Color, bottom := 0.0) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(extent.x/SCALE,height,extent.y/(SCALE*sin(TILT)))
	var obj := MeshInstance3D.new()
	obj.mesh = mesh
	obj.material_override = _mat(color)
	obj.position = ground(center,bottom+height*0.5)
	add_child(obj)
	return obj


func _building(rect: Rect2, h: float, wall: Color, roof: Color) -> void:
	_box(rect.get_center(),rect.size,h,wall)
	_box(rect.get_center(),rect.size+Vector2(8,7),0.12,roof.darkened(0.22),h)
	_box(rect.get_center(),rect.size-Vector2(5,5),0.10,roof,h+0.11)


func _front(pos: Vector2,h: float,tint: Color) -> void:
	_box(pos,Vector2(34,5),h,Color("#37494b"))
	_box(pos+Vector2(0,2),Vector2(25,3),h*0.8,tint,0.02)
	_box(pos+Vector2(0,6),Vector2(44,15),0.14,Color("#aaa490"))
	_box(pos+Vector2(0,2),Vector2(47,16),0.12,tint.darkened(0.16),h)


func _tree(pos: Vector2) -> void:
	_box(pos,Vector2(6,7),1.0,Color("#796754"))
	for i in range(2):
		var crown := CylinderMesh.new()
		crown.radial_segments = 6
		crown.top_radius = 0.08
		crown.bottom_radius = 0.66-i*0.13
		crown.height = 1.15
		var obj := MeshInstance3D.new()
		obj.mesh = crown
		obj.material_override = _mat(Color("#54685b") if i == 0 else Color("#6e7964"))
		obj.position = ground(pos,1.01+i*0.55)
		add_child(obj)


func _car(pos: Vector2) -> void:
	_box(pos,Vector2(56,24),0.38,Color("#78695b"),0.13)
	_box(pos+Vector2(-3,-2),Vector2(31,20),0.28,Color("#718080"),0.51)


func _lamp(at: Vector2) -> void:
	_box(at,Vector2(3,3),2.3,Color("#434d4d"))
	_box(at+Vector2(6,0),Vector2(16,4),0.085,Color("#867d67"),2.29)
	_box(at+Vector2(12,0),Vector2(7,6),0.12,Color("#ffda98"),2.19)
	var light := OmniLight3D.new()
	light.position = ground(at,2.05)
	light.light_color = Color("#ffbd79")
	light.omni_range = 5.0
	light.light_energy = 0.8
	add_child(light)
	lamps.append(light)


func night() -> void:
	following = true
	daylight.light_color = Color("#a8bbd5")
	daylight.light_energy = 0.8
	atmosphere.ambient_light_color = Color("#9db0be")
	atmosphere.ambient_light_energy = 0.63
	for light in lamps:
		light.light_energy = 2.4


func reveal() -> void:
	for seam in traces:
		seam.show()
	var glow := OmniLight3D.new()
	glow.position = ground(Vector2(1012,391),1.1)
	glow.light_color = Color("#5ceade")
	glow.omni_range = 4.5
	glow.light_energy = 2.8
	add_child(glow)


func turn(steps: int) -> void:
	view_index = posmod(view_index + steps, VIEW_NAMES.size())
	target_yaw += steps * PI * 0.5


func change_zoom(steps: int) -> void:
	zoom_index = clampi(zoom_index + steps, 0, ZOOM_STEPS.size() - 1)


func _place_camera(focus: Vector2) -> void:
	var pivot := ground(focus)
	var arm := Vector3(sin(yaw) * cos(TILT), sin(TILT), cos(yaw) * cos(TILT))
	camera.size = 720.0 / (SCALE * zoom_factor)
	camera.position = pivot + arm * 40.0
	camera.look_at(pivot)
	# Three ground samples define the same affine map as the orthographic renderer.
	var center := camera.unproject_position(ground(MAP_CENTER))
	var dx := (camera.unproject_position(ground(MAP_CENTER + Vector2(100, 0))) - center) / 100.0
	var dy := (camera.unproject_position(ground(MAP_CENTER + Vector2(0, 100))) - center) / 100.0
	ground_transform = Transform2D(dx, dy, center - dx * MAP_CENTER.x - dy * MAP_CENTER.y)


func sync(actor: PlayerController, delta: float) -> void:
	if courier == null:
		return
	yaw = move_toward(yaw, target_yaw, TAU * delta)
	zoom_factor = move_toward(zoom_factor, ZOOM_STEPS[zoom_index], 2.8 * delta)
	_place_camera(actor.position if following else MAP_CENTER)
	clock += delta
	var moving := actor.velocity.length_squared() > 1.0
	var bob := absf(sin(clock*12.0))*0.09 if moving else 0.0
	courier.position = ground(actor.position,0.015+bob)
	var screen_velocity := ground_transform.basis_xform(actor.velocity)
	if absf(screen_velocity.x) > 2.0:
		courier.flip_h = screen_velocity.x < 0.0
