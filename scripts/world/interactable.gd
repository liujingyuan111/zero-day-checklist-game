class_name Interactable
extends Area2D

signal state_changed

@export var interaction_enabled: bool = true
@export var pick_priority: int = 0

@export var object_kind: StringName = &"generic"
@export var object_label: String = "Object"
@export var interaction_range: float = 52.0
@export var object_hp: int = 3
@export var loot_item_id: StringName = &"scrap"
@export var loot_quantity: int = 1

var is_open: bool = false
var is_consumed: bool = false
var _base_color: Color = Color.WHITE
var _visual: Polygon2D
var _flash_tween: Tween


func _ready() -> void:
	add_to_group("interactable")
	collision_layer = 2
	collision_mask = 0
	monitoring = false
	monitorable = true
	input_pickable = true


func configure(kind: StringName, label: String, world_position: Vector2, color: Color, radius: float = 22.0) -> void:
	object_kind = kind
	object_label = label
	position = world_position
	_base_color = color

	_visual = Polygon2D.new()
	_visual.name = "Visual"
	_visual.color = color
	_visual.polygon = _shape_for_kind(kind, radius)
	add_child(_visual)

	var shadow := Polygon2D.new()
	shadow.name = "Shadow"
	shadow.color = Color(0.02, 0.03, 0.04, 0.25)
	shadow.polygon = PackedVector2Array([
		Vector2(-radius * 0.85, radius * 0.38),
		Vector2(0, radius * 0.18),
		Vector2(radius * 0.85, radius * 0.38),
		Vector2(0, radius * 0.62)
	])
	shadow.z_index = -1
	add_child(shadow)

	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var circle := CircleShape2D.new()
	circle.radius = radius
	collision.shape = circle
	collision.position = Vector2(0, 0)
	add_child(collision)


func get_available_actions(actor: PlayerController, held_item_id: StringName) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	if not interaction_enabled or is_consumed or is_queued_for_deletion():
		return actions
	match object_kind:
		&"tree":
			if held_item_id == &"axe":
				actions.append(_action(&"chop", "砍伐", 90, interaction_range, 0.58, &"axe"))
			else:
				actions.append(_action(&"inspect", "查看", 10, interaction_range, 0.25))
		&"chest":
			if not is_open:
				actions.append(_action(&"open", "打开", 80, interaction_range, 0.48))
			else:
				actions.append(_action(&"inspect", "查看", 10, interaction_range, 0.25))
		&"pickup":
			actions.append(_action(&"pick_up", "拾取", 100, interaction_range, 0.25))
		&"zombie":
			if object_hp > 0:
				actions.append(_action(&"attack", "攻击", 95, interaction_range, 0.42))
			else:
				actions.append(_action(&"inspect", "查看", 10, interaction_range, 0.25))
		_:
			actions.append(_action(&"inspect", "查看", 10, interaction_range, 0.25))
	return actions


func execute_action(action_id: StringName, actor: PlayerController) -> Dictionary:
	if not is_instance_valid(actor) or not interaction_enabled or is_consumed or is_queued_for_deletion():
		return {"success": false, "message": "目标已经失效。"}
	match action_id:
		&"chop":
			if object_kind != &"tree" or object_hp <= 0 or actor.equipped_item_id != &"axe":
				return {"success": false, "message": "需要装备斧头。"}
			object_hp -= 1
			if object_hp <= 0:
				is_consumed = true
				interaction_enabled = false
				actor.add_item(&"wood", 3)
				queue_free()
				return {"success": true, "message": "树木倒下，木材 +3。"}
			return {"success": true, "message": "砍伐生效，树木耐久：%d" % object_hp}
		&"open":
			if object_kind != &"chest" or is_open:
				return {"success": false, "message": "Already open."}
			is_open = true
			set_hovered(false)
			state_changed.emit()
			actor.add_item(&"canned_food", 2)
			return {"success": true, "message": "补给箱已打开，罐头 +2。"}
		&"pick_up":
			if object_kind != &"pickup" or is_consumed:
				return {"success": false, "message": "Already collected."}
			is_consumed = true
			actor.add_item(loot_item_id, loot_quantity)
			queue_free()
			return {"success": true, "message": "拾取%s ×%d。" % [object_label, loot_quantity]}
		&"attack":
			if object_kind != &"zombie" or object_hp <= 0:
				return {"success": false, "message": "No valid target."}
			object_hp -= 1
			if object_hp <= 0:
				is_consumed = true
				interaction_enabled = false
				actor.add_item(&"core_shard", 1)
				queue_free()
				return {"success": true, "message": "感染者倒下，核心碎片 +1。"}
			return {"success": true, "message": "攻击命中，感染者生命：%d" % object_hp}
		&"inspect":
			return {"success": true, "message": object_label}
	return {"success": false, "message": "Action not supported."}


func set_hovered(value: bool) -> void:
	if _visual == null:
		return
	var state_color := Color("#527c70") if is_open else _base_color
	_visual.color = state_color.lightened(0.35) if value else state_color


func flash_hit() -> void:
	if _visual == null:
		return
	var material := _visual.material as ShaderMaterial
	if material == null:
		material = ShaderMaterial.new()
		material.shader = preload("res://third_party/hit_flash/hit_flash.gdshader")
		_visual.material = material
	if _flash_tween != null:
		_flash_tween.kill()
	material.set_shader_parameter("active", true)
	_flash_tween = create_tween()
	_flash_tween.tween_interval(0.10)
	_flash_tween.tween_callback(func() -> void: material.set_shader_parameter("active", false))


func _action(id: StringName, label: String, priority: int, action_range: float, duration: float, required_item: StringName = &"") -> Dictionary:
	return {
		"id": id,
		"label": label,
		"priority": priority,
		"range": action_range,
		"duration": duration,
		"required_item_id": required_item,
		"commit_ratio": 0.45,
		"repeat": id == &"chop" or id == &"attack"
	}


func _shape_for_kind(kind: StringName, radius: float) -> PackedVector2Array:
	match kind:
		&"tree":
			return PackedVector2Array([
				Vector2(-radius * 0.62, radius * 0.35),
				Vector2(-radius * 0.28, -radius * 0.78),
				Vector2(0, -radius),
				Vector2(radius * 0.48, -radius * 0.72),
				Vector2(radius * 0.7, radius * 0.32),
				Vector2(0, radius * 0.72)
			])
		&"chest":
			return PackedVector2Array([
				Vector2(-radius, -radius * 0.45),
				Vector2(radius, -radius * 0.45),
				Vector2(radius, radius * 0.55),
				Vector2(-radius, radius * 0.55)
			])
		&"zombie":
			return PackedVector2Array([
				Vector2(0, -radius),
				Vector2(radius * 0.7, -radius * 0.25),
				Vector2(radius * 0.58, radius * 0.75),
				Vector2(-radius * 0.58, radius * 0.75),
				Vector2(-radius * 0.7, -radius * 0.25)
			])
		&"pickup":
			return PackedVector2Array([
				Vector2(0, -radius),
				Vector2(radius * 0.8, 0),
				Vector2(0, radius),
				Vector2(-radius * 0.8, 0)
			])
	return PackedVector2Array([
		Vector2(-radius, -radius),
		Vector2(radius, -radius),
		Vector2(radius, radius),
		Vector2(-radius, radius)
	])
