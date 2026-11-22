class_name PlayerController
extends CharacterBody2D

signal inventory_changed
signal equipment_changed(item_id: StringName)
signal navigation_failed(message: String)

@export var move_speed: float = 190.0
@export var stall_timeout: float = 0.8

var navigation_grid: NavigationGrid
var action_queue: ActionQueue
var animation_driver: ActionAnimationDriver
var visual_adapter: ActorVisualAdapter
var equipped_item_id: StringName = &"axe"
var inventory: Dictionary = {&"water": 2, &"bandage": 1}
var _path: PackedVector2Array = PackedVector2Array()
var _path_index: int = 0
var _stall_elapsed: float = 0.0
var _last_path_position: Vector2
var _path_navigation_revision: int = -1


func _ready() -> void:
	collision_layer = 1
	collision_mask = 1
	visual_adapter = get_node_or_null("Visual") as ActorVisualAdapter
	if visual_adapter == null:
		visual_adapter = ActorVisualAdapter.new()
		visual_adapter.name = "Visual"
		add_child(visual_adapter)
	animation_driver = ActionAnimationDriver.new()
	animation_driver.name = "ActionAnimationDriver"
	add_child(animation_driver)
	action_queue = ActionQueue.new()
	action_queue.name = "ActionQueue"
	action_queue.actor = self
	action_queue.navigation_grid = navigation_grid
	add_child(action_queue)


func _process(_delta: float) -> void:
	if is_instance_valid(visual_adapter) and is_instance_valid(animation_driver):
		visual_adapter.sync_action_progress(animation_driver.get_progress())


func _physics_process(delta: float) -> void:
	var input_direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_direction.length_squared() > 0.01:
		if action_queue.current_intent != null:
			action_queue.cancel_action("手动移动，中断动作")
		stop_path()
		velocity = input_direction.normalized() * move_speed
		face_direction(input_direction)
		move_and_slide()
		visual_adapter.set_motion(velocity.length_squared() > 1.0)
		return

	if not path_finished():
		_follow_step(delta)
	else:
		velocity = Vector2.ZERO
		move_and_slide()
	visual_adapter.set_motion(velocity.length_squared() > 1.0)


func _follow_step(delta: float) -> void:
	while _path_index < _path.size() and global_position.distance_to(_path[_path_index]) <= 2.5:
		_path_index += 1
	if path_finished():
		velocity = Vector2.ZERO
		return
	var destination := _path[_path_index]
	if navigation_grid != null and not navigation_grid.is_walkable_world(destination):
		stop_path()
		navigation_failed.emit("路径被新障碍阻断。")
		return
	if navigation_grid != null and _path_navigation_revision != navigation_grid.revision:
		_path_navigation_revision = navigation_grid.revision
		if not navigation_grid.has_movement_line(global_position, destination):
			stop_path()
			navigation_failed.emit("前方路径已被新障碍切断。")
			return
	var offset := destination - global_position
	velocity = offset.normalized() * minf(move_speed, offset.length() / maxf(delta, 0.0001))
	face_direction(offset)
	move_and_slide()
	if global_position.distance_squared_to(_last_path_position) < 0.04:
		_stall_elapsed += delta
	else:
		_stall_elapsed = 0.0
	_last_path_position = global_position
	if _stall_elapsed >= stall_timeout:
		stop_path()
		navigation_failed.emit("路径受阻，角色已停止。")


func follow_path(points: PackedVector2Array) -> void:
	_path = points.duplicate()
	_path_index = 0
	_stall_elapsed = 0.0
	_last_path_position = global_position
	_path_navigation_revision = navigation_grid.revision if navigation_grid != null else -1
	if _path.size() > 0 and global_position.distance_to(_path[0]) <= 2.5:
		_path_index = 1


func move_to_position(destination: Vector2) -> bool:
	if navigation_grid == null:
		return false
	var points := navigation_grid.find_path(global_position, destination)
	if points.is_empty():
		stop_path()
		return false
	follow_path(points)
	return true


func path_finished() -> bool:
	return _path_index >= _path.size()


func stop_path() -> void:
	_path = PackedVector2Array()
	_path_index = 0
	_stall_elapsed = 0.0
	velocity = Vector2.ZERO


func path_preview() -> PackedVector2Array:
	var result := PackedVector2Array([global_position])
	for i in range(_path_index, _path.size()):
		result.append(_path[i])
	return result


func face_position(target_position: Vector2) -> void:
	face_direction(target_position - global_position)


func face_direction(direction: Vector2) -> void:
	if is_instance_valid(visual_adapter):
		visual_adapter.face_direction(direction)


func play_action(action_id: StringName, duration: float, token: int = 0, commit_ratio: float = 0.45) -> void:
	visual_adapter.begin_action(action_id, duration)
	animation_driver.play_action(action_id, token, duration, commit_ratio)


func cancel_action_visual() -> void:
	if is_instance_valid(animation_driver):
		animation_driver.cancel_action()
	if is_instance_valid(visual_adapter):
		visual_adapter.cancel_action()


func on_action_commit(action_id: StringName) -> void:
	if is_instance_valid(visual_adapter):
		visual_adapter.on_commit(action_id)


func equip_item(item_id: StringName) -> void:
	if equipped_item_id == item_id:
		return
	if is_instance_valid(action_queue):
		action_queue.cancel_action("更换装备，中断当前动作")
	equipped_item_id = item_id
	equipment_changed.emit(item_id)


func add_item(item_id: StringName, amount: int) -> void:
	if amount <= 0:
		return
	inventory[item_id] = int(inventory.get(item_id, 0)) + amount
	inventory_changed.emit()


func has_items(cost: Dictionary) -> bool:
	for item_id in cost:
		if int(cost[item_id]) <= 0 or int(inventory.get(item_id, 0)) < int(cost[item_id]):
			return false
	return true


func spend_items(cost: Dictionary, on_paid: Callable = Callable()) -> bool:
	if not has_items(cost):
		return false
	for item_id in cost:
		var left := int(inventory[item_id]) - int(cost[item_id])
		if left == 0:
			inventory.erase(item_id)
		else:
			inventory[item_id] = left
	if on_paid.is_valid():
		on_paid.call()
	inventory_changed.emit()
	return true


func inventory_summary() -> String:
	var parts: PackedStringArray = []
	var keys := inventory.keys()
	keys.sort()
	for key in keys:
		parts.append("%s ×%d" % [String(key), int(inventory[key])])
	return ", ".join(parts)
