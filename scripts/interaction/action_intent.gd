class_name ActionIntent
extends RefCounted

## One active command. Each swing gets a new sequence token.
enum Status { QUEUED, APPROACHING, WINDUP, RECOVERY, COMPLETED, CANCELLED, FAILED }

var actor: PlayerController
var target: Interactable
var action_data: Dictionary = {}
var status: Status = Status.QUEUED
var token: int = 0
var committed: bool = false
var path_attempts: int = 0
var approach_elapsed: float = 0.0
var execution_elapsed: float = 0.0
var repath_elapsed: float = 0.0
var planned_target_position: Vector2 = Vector2.ZERO
var last_result: Dictionary = {}


func _init(p_actor: PlayerController = null, p_target: Interactable = null, p_action_data: Dictionary = {}) -> void:
	actor = p_actor
	target = p_target
	action_data = p_action_data.duplicate(true)


func action_id() -> StringName:
	return StringName(action_data.get("id", &"inspect"))
