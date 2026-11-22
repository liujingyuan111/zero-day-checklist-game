class_name ActionQueue
extends Node

## One buffered intent, not a batch queue. Last valid command wins.
signal status_changed(message: String)
signal action_committed(token: int, action_id: StringName, result: Dictionary)
signal intent_finished(token: int, reason: String)

@export var repeat_enabled: bool = true
@export var approach_timeout: float = 18.0
@export var repath_interval: float = 0.25

var actor: PlayerController
var navigation_grid: NavigationGrid
var current_intent: ActionIntent
var _next_token: int = 0
var _command_revision: int = 0


func _ready() -> void:
	if is_instance_valid(actor):
		actor.animation_driver.commit_requested.connect(_on_commit_requested)
		actor.animation_driver.sequence_finished.connect(_on_sequence_finished)
		actor.navigation_failed.connect(_on_navigation_failed)


func request_action(target: Interactable, action_data: Dictionary) -> void:
	if action_data.is_empty():
		status_changed.emit("没有可执行动作。")
		return
	var fresh := ActionResolver.resolve_id(actor, target, StringName(action_data.get("id", &"")))
	if fresh.is_empty():
		status_changed.emit("动作条件已变化，请重新选择。")
		return
	var expected_revision := _command_revision + 1
	cancel_action("切换目标")
	if _command_revision == expected_revision:
		_start_intent(target, fresh)


func _start_intent(target: Interactable, action_data: Dictionary) -> void:
	var intent := ActionIntent.new(actor, target, action_data)
	intent.token = _allocate_token()
	current_intent = intent
	if _within_reach(intent):
		_execute(intent)
	else:
		_plan_approach(intent)


func _physics_process(delta: float) -> void:
	var intent := current_intent
	if intent == null:
		return
	if intent.status == ActionIntent.Status.RECOVERY:
		_check_animation_timeout(intent, delta)
		return
	if not _target_valid(intent):
		_fail(intent, "目标已消失或停止交互。")
		return
	if ActionResolver.resolve_id(actor, intent.target, intent.action_id()).is_empty():
		_fail(intent, "装备或目标状态已变化，动作停止。")
		return
	if intent.status == ActionIntent.Status.WINDUP:
		_check_animation_timeout(intent, delta)
		return
	if intent.status != ActionIntent.Status.APPROACHING:
		return
	intent.approach_elapsed += delta
	intent.repath_elapsed += delta
	if intent.approach_elapsed >= approach_timeout:
		_fail(intent, "接近目标超时，已停止。")
		return
	if _within_reach(intent):
		_execute(intent)
		return
	var target_moved := intent.planned_target_position.distance_to(intent.target.global_position) >= 12.0
	if actor.path_finished() or (target_moved and intent.repath_elapsed >= repath_interval):
		_plan_approach(intent)


func _check_animation_timeout(intent: ActionIntent, delta: float) -> void:
	intent.execution_elapsed += delta
	if intent.execution_elapsed > float(intent.action_data.get("duration", 0.4)) + 1.5:
		_fail(intent, "动画没有发出结束事件，已安全停止。")


func cancel_action(reason: String = "已取消") -> void:
	_command_revision += 1
	var cancel_revision := _command_revision
	var intent := current_intent
	current_intent = null
	if is_instance_valid(actor):
		actor.stop_path()
		actor.cancel_action_visual()
	if intent == null:
		return
	intent.status = ActionIntent.Status.CANCELLED
	intent_finished.emit(intent.token, "cancelled_after_commit" if intent.committed else "cancelled")
	if _command_revision == cancel_revision:
		status_changed.emit(reason + ("（已命中的结果保留）" if intent.committed else ""))


func _plan_approach(intent: ActionIntent) -> void:
	if current_intent != intent or not _target_valid(intent):
		return
	if navigation_grid == null:
		_fail(intent, "尚未配置导航。")
		return
	var action_range := float(intent.action_data.get("range", intent.target.interaction_range))
	var path := navigation_grid.find_approach_path(actor.global_position, intent.target.global_position, action_range)
	if path.is_empty():
		_fail(intent, "目标不可达：找不到范围内、无遮挡的站位。")
		return
	intent.status = ActionIntent.Status.APPROACHING
	intent.planned_target_position = intent.target.global_position
	intent.repath_elapsed = 0.0
	actor.follow_path(path)
	status_changed.emit("正在接近：%s" % String(intent.action_data.get("label", "目标")))


func _execute(intent: ActionIntent) -> void:
	if current_intent != intent or not _target_valid(intent):
		return
	var fresh := ActionResolver.resolve_id(actor, intent.target, intent.action_id())
	if fresh.is_empty():
		_fail(intent, "动作条件不再满足。")
		return
	intent.action_data = fresh
	intent.status = ActionIntent.Status.WINDUP
	intent.execution_elapsed = 0.0
	actor.stop_path()
	actor.face_position(intent.target.global_position)
	actor.play_action(intent.action_id(), float(fresh.get("duration", 0.4)), intent.token, float(fresh.get("commit_ratio", 0.45)))
	status_changed.emit("动作前摇：%s" % String(fresh.get("label", intent.action_id())))


func _on_commit_requested(token: int) -> void:
	var intent := current_intent
	if intent == null or intent.token != token or intent.committed or intent.status != ActionIntent.Status.WINDUP:
		return
	if not _target_valid(intent):
		_fail(intent, "生效前目标消失。")
		return
	var fresh := ActionResolver.resolve_id(actor, intent.target, intent.action_id())
	if fresh.is_empty():
		_fail(intent, "生效前装备或条件改变。")
		return
	if not _within_reach(intent):
		actor.cancel_action_visual()
		var old_token := intent.token
		intent.token = _allocate_token()
		intent_finished.emit(old_token, "reapproach")
		if current_intent == intent:
			_plan_approach(intent)
		return
	# Mark before external target logic: it may destroy itself in this callback.
	intent.committed = true
	intent.status = ActionIntent.Status.RECOVERY
	var effect_position := intent.target.global_position
	intent.last_result = intent.target.execute_action(intent.action_id(), actor)
	if not bool(intent.last_result.get("success", false)):
		_fail(intent, String(intent.last_result.get("message", "动作失败。")))
		return
	intent.last_result["world_position"] = effect_position
	if intent.action_id() in [&"chop", &"attack"] and is_instance_valid(intent.target) and not intent.target.is_queued_for_deletion():
		intent.target.flash_hit()
	if current_intent == intent:
		actor.on_action_commit(intent.action_id())
	action_committed.emit(token, intent.action_id(), intent.last_result.duplicate(true))
	if current_intent == intent:
		status_changed.emit(String(intent.last_result.get("message", "动作生效。")))


func _on_sequence_finished(token: int) -> void:
	var intent := current_intent
	if intent == null or intent.token != token:
		return
	if not intent.committed:
		_fail(intent, "动画缺少生效事件。")
		return
	var finish_revision := _command_revision
	intent.status = ActionIntent.Status.COMPLETED
	current_intent = null
	actor.cancel_action_visual()
	intent_finished.emit(token, "completed")
	if current_intent != null or _command_revision != finish_revision:
		return
	if repeat_enabled and bool(intent.action_data.get("repeat", false)) and _target_valid(intent):
		var next_action := ActionResolver.resolve_id(actor, intent.target, intent.action_id())
		if not next_action.is_empty():
			_start_intent(intent.target, next_action)


func _on_navigation_failed(message: String) -> void:
	var intent := current_intent
	if intent == null or intent.status != ActionIntent.Status.APPROACHING:
		return
	intent.path_attempts += 1
	if intent.path_attempts > 2:
		_fail(intent, message)
	else:
		_plan_approach(intent)


func _within_reach(intent: ActionIntent) -> bool:
	if not _target_valid(intent):
		return false
	var distance := actor.global_position.distance_to(intent.target.global_position)
	var reach := float(intent.action_data.get("range", intent.target.interaction_range))
	if distance > reach + 0.5:
		return false
	return navigation_grid == null or navigation_grid.has_interaction_line(actor.global_position, intent.target.global_position)


func _target_valid(intent: ActionIntent) -> bool:
	return is_instance_valid(actor) and is_instance_valid(intent.target) and not intent.target.is_queued_for_deletion() and intent.target.interaction_enabled and not intent.target.is_consumed


func _fail(intent: ActionIntent, message: String) -> void:
	if current_intent != intent:
		return
	current_intent = null
	intent.status = ActionIntent.Status.FAILED
	actor.stop_path()
	actor.cancel_action_visual()
	intent_finished.emit(intent.token, "failed")
	status_changed.emit(message)


func _allocate_token() -> int:
	_next_token += 1
	return _next_token


func debug_state() -> String:
	if current_intent == null:
		return "IDLE"
	return "%s  #%d%s" % [ActionIntent.Status.keys()[current_intent.status], current_intent.token, " / 已结算" if current_intent.committed else ""]
