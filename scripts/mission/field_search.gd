class_name FieldSearch
extends Node

signal scanned(origin: Vector2, marks: Array[Vector2], discoveries: int)

const RADIUS := 165.0
const COOLDOWN_SECONDS := 3
var actor: PlayerController
var targets: Node2D
var concealed: Array[Interactable] = []
var _cooldown := ManualCooldown.new()


func conceal(item: Interactable) -> void:
	item.hide()
	item.interaction_enabled = false
	concealed.append(item)


func _physics_process(_delta: float) -> void:
	if _cooldown.is_ongoing():
		_cooldown.tick()


func seconds_left() -> int:
	return ceili(float(_cooldown.get_remaining()) / Engine.physics_ticks_per_second)


func use() -> bool:
	if _cooldown.is_ongoing():
		return false
	_cooldown.start(COOLDOWN_SECONDS * Engine.physics_ticks_per_second)
	var origin := actor.global_position
	var marks: Array[Vector2] = []
	var found := 0
	for child in targets.get_children():
		var item := child as Interactable
		if item == null or item.is_queued_for_deletion() or item.is_consumed or item.is_open:
			continue
		if origin.distance_squared_to(item.global_position) > RADIUS * RADIUS:
			continue
		if not actor.navigation_grid.has_interaction_line(origin, item.global_position):
			continue
		if item in concealed:
			concealed.erase(item)
			item.interaction_enabled = true
			item.show()
			found += 1
		if item.interaction_enabled and item.is_visible_in_tree():
			marks.append(item.global_position)
	scanned.emit(origin, marks, found)
	return true
