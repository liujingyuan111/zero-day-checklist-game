## Cooldown variant that runs for a number of discrete "ticks"
## which have to be manually pushed.

extends RefCounted

class_name ManualCooldown

var _duration_ticks: int = 0
var _elapsed_ticks: int = 0
var _initialized: bool = false
var _paused: bool = false


## Creates a new ManualCooldown
## Optionally accepts a default duration in ticks
func _init(duration_ticks: int = 0) -> void:
    if duration_ticks < 0:
        push_error("duration_ticks must be a non-negative number")
    _duration_ticks = max(duration_ticks, 0.0)


## Starts the cooldown with a given duration in ticks
## If no duration is provided, the last defined duration will be used
func start(duration_ticks: int = 0) -> void:
    if duration_ticks <= 0:
        if _duration_ticks <= 0:
            push_error("duration_ticks must be a positive integer or a previous duration must have been set")
            return
        duration_ticks = _duration_ticks  # Use the last defined duration

    _duration_ticks = duration_ticks
    _elapsed_ticks = 0
    _initialized = true
    _paused = false


## Pauses the cooldown until resume is called
func pause() -> void:
    if not _initialized:
        push_warning("Trying to pause a cooldown that has not been initialized")
        return

    if _paused:
        return

    _paused = true


## Resumes the cooldown from a paused state
func resume() -> void:
    if not _paused:
        return

    if not _initialized:
        return

    _paused = false


## Checks if the cooldown is currently paused
func is_paused() -> bool:
    return _paused


## Advances the countdown by one tick
func tick() -> void:
    if not _initialized:
        return

    if _paused:
        return

    _elapsed_ticks += 1


## Checks if the cooldown has been started, but hasn't yet finished
## Unaffected by pause
func is_ongoing() -> bool:
    return _initialized and not is_finished()


## Checks if the countdown is finished (i.e. ready / expired)
func is_finished() -> bool:
    if not _initialized:
        return false
    return _elapsed_ticks >= _duration_ticks


## Gets the remaining number of ticks
func get_remaining() -> int:
    if not _initialized:
        return 0
    return max(_duration_ticks - _elapsed_ticks, 0)


## Gets the progress of the countdown as a percentage (0.0 - 1.0)
func get_progress() -> float:
    if not _initialized:
        return 0.0
    var progress = float(_elapsed_ticks) / float(_duration_ticks)
    return clamp(progress, 0.0, 1.0)


## Sets the progress of the countdown to a given percentage (0.0 - 1.0)
## NOTE: rounded to the nearest tick
## Unaffected by pause
func set_progress(progress: float) -> void:
    if not _initialized:
        push_warning("Trying to set the progress of a cooldown that has not been initialized")
        return
    _elapsed_ticks = clampi(int(round(progress * float(_duration_ticks))), 0, _duration_ticks)


## Advances the countdown by a given progress percentage (0.0 - 1.0)
## Unaffected by pause
## NOTE: changes resulting in less that 0.5 of a tick will be not have any effect
##
## Same as set_progress(get_progress() + progress)
func advance(progress: float) -> void:
    set_progress(get_progress() + progress)


## Rewinds the countdown by a given progress percentage (0.0 - 1.0)
## Unaffected by pause
## NOTE: changes resulting in less that 0.5 of a tick will be not have any effect
##
## Same as set_progress(get_progress() - progress)
func rewind(progress: float) -> void:
    set_progress(get_progress() - progress)


## Immediately marks this cooldown as finished
## Unaffected by pause
##
## Same as set_progress(1.0)
func finish() -> void:
    set_progress(1.0)


## Gets the elapsed number of ticks
func get_elapsed() -> int:
    if not _initialized:
        return 0
    return _elapsed_ticks
