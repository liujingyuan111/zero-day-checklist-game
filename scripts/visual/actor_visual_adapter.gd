class_name ActorVisualAdapter
extends Node2D
## Art-only adapter. The parent remains the foot position used by physics/Y-sort.
## No gameplay effects and no continuous rotation of the sprite root.

@export var sprite_frames: SpriteFrames:
	set(value):
		sprite_frames = value
		if is_instance_valid(_sprite):
			_sprite.sprite_frames = value
			_refresh_animation(true)
@export_enum("Four directions:4", "Eight directions:8") var direction_count: int = 8
@export var foot_anchor: Vector2 = Vector2(32.0, 60.0)
@export_range(1, 4, 1) var art_scale: int = 1
@export var body_color: Color = Color("d4c39f")
@export var accent_color: Color = Color("67d6c1")

var facing: StringName = &"s"
var _direction: Vector2 = Vector2.DOWN
var _moving: bool = false
var _action: StringName = &""
var _action_duration: float = 0.4
var _elapsed: float = 0.0
var _walk_clock: float = 0.0
var _flash_remaining: float = 0.0
var _external_progress: bool = false
var _sprite: AnimatedSprite2D
var _using_sprite: bool = false


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "ArtSprite"
	_sprite.centered = false
	_sprite.offset = -foot_anchor
	_sprite.scale = Vector2.ONE * float(art_scale)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.sprite_frames = sprite_frames
	add_child(_sprite)
	_refresh_animation(true)


func face_direction(direction: Vector2) -> void:
	if direction.length_squared() < 0.0001:
		return
	_direction = direction.normalized()
	var names: Array[StringName] = [&"e", &"se", &"s", &"sw", &"w", &"nw", &"n", &"ne"]
	var count := 8 if direction_count == 8 else 4
	var index := posmod(roundi(_direction.angle() / (TAU / float(count))), count)
	var next_facing: StringName = names[index if count == 8 else index * 2]
	if next_facing != facing:
		facing = next_facing
		_refresh_animation()
	queue_redraw()


func set_motion(moving: bool) -> void:
	if _moving == moving:
		return
	_moving = moving
	if _action.is_empty():
		_refresh_animation()
	queue_redraw()


func begin_action(action_id: StringName, duration: float) -> void:
	_action = action_id
	_action_duration = clampf(duration if is_finite(duration) else 0.4, 0.08, 30.0)
	_elapsed = 0.0
	_flash_remaining = 0.0
	_external_progress = false
	_refresh_animation(true)
	queue_redraw()


func cancel_action() -> void:
	_action = &""
	_elapsed = 0.0
	_flash_remaining = 0.0
	_external_progress = false
	_refresh_animation(true)
	queue_redraw()


func on_commit(_action_id: StringName) -> void:
	# Cosmetic acknowledgement only. The queue already owns the actual result.
	_flash_remaining = 0.12
	queue_redraw()


func sync_action_progress(progress: float) -> void:
	# Optional exact alignment with ActionAnimationDriver.get_progress(). Useful
	# for authored impact frames and for slow-motion/debug inspection.
	if _action.is_empty():
		return
	_external_progress = true
	_elapsed = clampf(progress, 0.0, 1.0) * _action_duration
	if _using_sprite and is_instance_valid(_sprite):
		_set_sprite_progress(progress)
	queue_redraw()


func _process(delta: float) -> void:
	_walk_clock += delta if _moving else 0.0
	_flash_remaining = maxf(0.0, _flash_remaining - delta)
	if not _action.is_empty() and not _external_progress:
		_elapsed = minf(_action_duration, _elapsed + delta)
		if _using_sprite:
			_set_sprite_progress(_elapsed / _action_duration)
	if is_instance_valid(_sprite):
		_sprite.self_modulate = Color.WHITE.lightened(0.1) if _flash_remaining > 0.0 else Color.WHITE
	queue_redraw()


func _refresh_animation(restart: bool = false) -> void:
	if not is_instance_valid(_sprite):
		return
	var state: StringName = _action if not _action.is_empty() else (&"walk" if _moving else &"idle")
	var chosen: StringName = &""
	var options: Array[StringName] = [
		StringName("%s_%s" % [state, facing]), state,
		StringName("idle_%s" % facing), &"idle"
	]
	if sprite_frames != null:
		for candidate in options:
			if sprite_frames.has_animation(candidate) and sprite_frames.get_frame_count(candidate) > 0:
				chosen = candidate
				break
	_using_sprite = not chosen.is_empty()
	_sprite.visible = _using_sprite
	if not _using_sprite:
		queue_redraw()
		return
	if restart or _sprite.animation != chosen:
		_sprite.stop()
		_sprite.animation = chosen
		_sprite.frame = 0
		_sprite.frame_progress = 0.0
	if _action.is_empty():
		_sprite.play(chosen)
	else:
		# Manual visual sampling keeps even incorrectly-looping authored clips
		# bounded to one action. It never emits the gameplay commit event.
		_sprite.pause()
		_set_sprite_progress(_elapsed / _action_duration)
	queue_redraw()


func _set_sprite_progress(progress: float) -> void:
	if sprite_frames == null or not is_instance_valid(_sprite):
		return
	var clip := _sprite.animation
	var count := sprite_frames.get_frame_count(clip)
	if count <= 0:
		return
	var total := 0.0
	for index in range(count):
		total += sprite_frames.get_frame_duration(clip, index)
	var cursor := clampf(progress, 0.0, 1.0) * total
	for index in range(count):
		var weight := sprite_frames.get_frame_duration(clip, index)
		if cursor < weight or index == count - 1:
			_sprite.set_frame_and_progress(index, clampf(cursor / maxf(weight, 0.001), 0.0, 1.0))
			return
		cursor -= weight


func _draw() -> void:
	# Geometric test actor, intentionally not a proposed final art direction.
	draw_set_transform(Vector2(0, 1), 0.0, Vector2(1.0, 0.38))
	draw_circle(Vector2.ZERO, 14.0, Color(0.02, 0.03, 0.04, 0.38))
	draw_set_transform(Vector2.ZERO)
	if not _using_sprite:
		var bob := float(roundi(sin(_walk_clock * 13.0) * 1.5)) if _moving else 0.0
		var base := body_color.lightened(0.2) if _flash_remaining > 0.0 else body_color
		draw_rect(Rect2(-11, -28 + bob, 22, 24), Color("263a43"))
		draw_rect(Rect2(-9, -27 + bob, 18, 22), base)
		draw_rect(Rect2(-7, -41 + bob, 14, 14), Color("b98c70"))
		draw_rect(Rect2(-8, -44 + bob, 16, 7), Color("253541"))
		draw_rect(Rect2(-8, -6, 6, 6), Color("202a31"))
		draw_rect(Rect2(2, -6, 6, 6), Color("202a31"))
		var eye := Vector2(roundf(_direction.x * 5.0), -34.0 + roundf(_direction.y * 2.0) + bob)
		draw_rect(Rect2(eye - Vector2.ONE * 1.5, Vector2(3, 3)), accent_color)
		if not _action.is_empty():
			var phase := clampf(_elapsed / _action_duration, 0.0, 1.0)
			var reach := 17.0 + sin(phase * PI) * 12.0
			var hand := Vector2(0, -16) + _direction * reach
			draw_line(Vector2(0, -16), hand, accent_color, 3.0)
			draw_rect(Rect2(hand - Vector2(3, 3), Vector2(6, 6)), base)
	if _flash_remaining > 0.0:
		var center := _direction * 28.0 + Vector2(0, -10)
		draw_arc(center, 7.0, 0.0, TAU, 12, accent_color, 2.0)
