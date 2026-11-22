class_name ActionAnimationDriver
extends Node
## Animation event source. It never applies damage, transfers items, or reads a target.
## The action queue owns those effects and must validate token + world state at commit.

signal commit_requested(token: int)
signal sequence_finished(token: int)

const MIN_DURATION: float = 0.08
const MAX_DURATION: float = 30.0

var _animation_player: AnimationPlayer
var _library: AnimationLibrary
var _active_name: StringName = &""
var _active_token: int = -1
var _generation: int = 0
var _running: bool = false
var _committed: bool = false
var _duration: float = 1.0
var _last_progress: float = 0.0


func _ready() -> void:
	_ensure_player()


func play_action(action_id: StringName, token: int, duration: float, commit_ratio: float = 0.45) -> void:
	_ensure_player()
	cancel_action()
	_duration = clampf(duration if is_finite(duration) else 0.4, MIN_DURATION, MAX_DURATION)
	var safe_ratio := clampf(commit_ratio if is_finite(commit_ratio) else 0.45, 0.05, 0.95)
	_active_token = token
	_active_name = StringName("action_%d" % _generation)
	_running = true
	_committed = false
	_last_progress = 0.0

	var clip := Animation.new()
	clip.resource_name = String(action_id)
	clip.length = _duration
	clip.loop_mode = Animation.LOOP_NONE
	var methods := clip.add_track(Animation.TYPE_METHOD)
	clip.track_set_path(methods, NodePath("."))
	# Immutable arguments belong to this clip. A deferred event from a cancelled
	# animation cannot borrow the new action's token or generation.
	clip.track_insert_key(methods, _duration * safe_ratio, {
		"method": &"_commit_for_sequence", "args": [token, _generation]
	})
	clip.track_insert_key(methods, _duration, {
		"method": &"_finish_for_sequence", "args": [token, _generation]
	})
	_library.add_animation(_active_name, clip)
	_animation_player.play(_active_name)


func cancel_action() -> void:
	# Invalidate first: stop/reset may share the frame with queued method calls.
	_generation += 1
	_running = false
	_committed = false
	_active_token = -1
	_last_progress = 0.0
	if is_instance_valid(_animation_player):
		# Keep-state avoids seeking an already-removed clip when a cancellation
		# is immediately followed by another play/cancel call in the same frame.
		_animation_player.stop(true)
		_animation_player.clear_queue()
	if _library != null and not _active_name.is_empty() and _library.has_animation(_active_name):
		_library.remove_animation(_active_name)
	_active_name = &""


func get_progress() -> float:
	if not _running or not is_instance_valid(_animation_player):
		return _last_progress
	return clampf(_animation_player.current_animation_position / _duration, 0.0, 1.0)


func is_running() -> bool:
	return _running


func _ensure_player() -> void:
	if is_instance_valid(_animation_player):
		return
	_animation_player = AnimationPlayer.new()
	_animation_player.name = "ActionTimeline"
	_animation_player.root_node = NodePath("..")
	_animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
	_animation_player.callback_mode_method = AnimationMixer.ANIMATION_CALLBACK_MODE_METHOD_DEFERRED
	_library = AnimationLibrary.new()
	_animation_player.add_animation_library(&"", _library)
	add_child(_animation_player)


func _commit_for_sequence(token: int, generation: int) -> void:
	if not _running or generation != _generation or token != _active_token or _committed:
		return
	_committed = true
	commit_requested.emit(token)


func _finish_for_sequence(token: int, generation: int) -> void:
	if not _running or generation != _generation or token != _active_token:
		return
	_running = false
	_last_progress = 1.0
	# Do not synthesize a missing commit here. The queue must reject an action
	# that finishes without a successful commit.
	sequence_finished.emit(token)
