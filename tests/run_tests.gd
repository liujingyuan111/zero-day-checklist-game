extends SceneTree
## Behaviour-level regression suite. No third-party test framework required.
## Run after import: godot --headless --path . --script tests/run_tests.gd
## Assertions exercise real physics frames and AnimationPlayer commit events.

var _world: Node2D
var _grid: NavigationGrid
var _actor: PlayerController
var _queue: ActionQueue
var _picker: WorldPicker
var _controller: InteractionController
var _commits: Array[Dictionary] = []
var _finishes: Array[Dictionary] = []
var _assertions: Array[Dictionary] = []
var _results: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for action_name in [&"move_left", &"move_right", &"move_up", &"move_down"]:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
	var cases: Array[Dictionary] = [
		{"id": "I01", "name": "Remote chest approach and one-time loot", "run": _test_remote_chest},
		{"id": "I02", "name": "Single request repeats chopping to completion", "run": _test_repeat_chop},
		{"id": "I03", "name": "Single request repeats attacks to completion", "run": _test_repeat_attack},
		{"id": "I04", "name": "Pickup commits once and invalidates target", "run": _test_pickup},
		{"id": "I05", "name": "Cancellation before commit has no effect", "run": _test_cancel_windup},
		{"id": "I06", "name": "Cancellation after commit preserves effect and stops repeat", "run": _test_cancel_recovery},
		{"id": "I07", "name": "Duplicate commit token cannot duplicate effects", "run": _test_duplicate_commit},
		{"id": "I08", "name": "Stale token cannot commit a replacement action", "run": _test_stale_token},
		{"id": "I09", "name": "Replacing an action cancels its pending effect", "run": _test_replace_windup},
		{"id": "I10", "name": "Cached action is rejected after equipment changes", "run": _test_stale_equipment_request},
		{"id": "I11", "name": "Equipment changes during approach invalidate work", "run": _test_equipment_during_approach},
		{"id": "I12", "name": "Equipment changes during windup prevent damage", "run": _test_equipment_during_windup},
		{"id": "I13", "name": "Near target behind wall is approached around wall", "run": _test_wall_occlusion},
		{"id": "I14", "name": "Unreachable target fails without loot or endless walking", "run": _test_unreachable},
		{"id": "I15", "name": "Moving target is followed to its new location", "run": _test_moving_target},
		{"id": "I16", "name": "Target leaving windup range cannot be hit remotely", "run": _test_target_moves_during_windup},
		{"id": "I17", "name": "Target deletion during approach terminates safely", "run": _test_target_deleted_approach},
		{"id": "I18", "name": "Target deletion during windup has no delayed reward", "run": _test_target_deleted_windup},
		{"id": "I19", "name": "Manual input interrupts buffered approach", "run": _test_manual_cancel},
		{"id": "I20", "name": "Right-click event cancels approach", "run": _test_right_click_cancel},
		{"id": "I21", "name": "Overlapping pick targets follow visual depth and deletion", "run": _test_picker_overlap},
		{"id": "I22", "name": "Click movement respects clearance around a solid wall", "run": _test_navigation_clearance},
		{"id": "I23", "name": "New blocking wall terminates an obsolete approach", "run": _test_dynamic_obstacle},
		{"id": "I24", "name": "Stopped animation is bounded by watchdog", "run": _test_missing_animation_event},
		{"id": "I25", "name": "Completion callback command takes precedence over repeat", "run": _test_completion_callback_reentry},
		{"id": "I26", "name": "Inventory callback replacement keeps its own commit timing", "run": _test_inventory_callback_reentry},
		{"id": "I27", "name": "Reapproach callback replacement is not overwritten", "run": _test_reapproach_callback_reentry},
		{"id": "M01", "name": "Hidden salvage, scan range, line of sight and cooldown", "run": _test_field_search},
		{"id": "M02", "name": "Wreck body click approaches a separate working position and discovers salvage", "run": _test_wreck_click},
		{"id": "M03", "name": "Missing materials, pre-commit interruption and material loss keep the bridge closed", "run": _test_repair_interrupt},
		{"id": "M04", "name": "Repair is atomic and survives cancellation and signal reentry", "run": _test_repair_atomic},
		{"id": "M05", "name": "Playable main scene completes a round trip by navigating to each target", "run": _test_supply_run},
		{"id": "N01", "name": "Budget, stock limits, refunds and manifest lock", "run": _test_night_budget},
		{"id": "N02", "name": "Same loadout, single-use sense changes the chosen route", "run": _test_night_sense},
		{"id": "N03", "name": "Rain cover, fuel and a wet shelter change dawn health", "run": _test_night_loadouts},
		{"id": "N04", "name": "Default scene, door picking, navigation, cancel and settlement", "run": _test_night_scene},
		{"id": "N05", "name": "Eating at home changes the dawn outcome for a risky trip", "run": _test_night_meal},
		{"id": "N06", "name": "Survival limits and inclusive damage thresholds", "run": _test_night_thresholds},
		{"id": "N07", "name": "Camera controls, zoom limits and input projection through the viewport", "run": _test_camera_controls},
	]
	var failure_count := 0
	for test_case in cases:
		_assertions = []
		var started := Time.get_ticks_msec()
		await test_case["run"].call()
		var passed := not _assertions.is_empty()
		for check in _assertions:
			passed = passed and bool(check["passed"])
		if not passed:
			failure_count += 1
		var outcome := {
			"id": test_case["id"], "name": test_case["name"], "passed": passed,
			"elapsed_ms": Time.get_ticks_msec() - started, "assertions": _assertions.duplicate(true)
		}
		_results.append(outcome)
		print("%s %s %s" % ["PASS" if passed else "FAIL", test_case["id"], test_case["name"]])
		if not passed:
			for check in _assertions:
				if not bool(check["passed"]):
					print("  FAILED: %s" % String(check["description"]))
	await _dispose_fixture()
	var report := {
		"suite": "ZeroDay first-night, supply mission and interaction regression",
		"engine": Engine.get_version_info(),
		"generated_at_utc": Time.get_datetime_string_from_system(true) + "Z",
		"execution": "Godot headless; real engine physics and AnimationPlayer; no GPU visual validation",
		"total": _results.size(), "passed": _results.size() - failure_count,
		"failed": failure_count, "cases": _results,
		"not_covered": ["Windows device performance", "final pixel-art lighting", "subjective input feel", "GUI click consumption over real buttons"]
	}
	var file := FileAccess.open("res://tests/latest_report.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t") + "\n")
		file.close()
	else:
		push_error("Unable to write tests/latest_report.json")
		failure_count += 1
	print("SUMMARY %d/%d passed; report: tests/latest_report.json" % [_results.size() - failure_count, _results.size()])
	quit(0 if failure_count == 0 else 1)


func _new_fixture(position: Vector2 = Vector2(128, 256)) -> void:
	await _dispose_fixture()
	_commits = []
	_finishes = []
	_world = Node2D.new()
	_world.name = "TestWorld"
	root.add_child(_world)
	_grid = NavigationGrid.new()
	_grid.name = "NavigationGrid"
	_world.add_child(_grid)
	_grid.configure(Vector2i(40, 23), Vector2(32, 32), Vector2.ZERO)
	_actor = PlayerController.new()
	_actor.name = "Player"
	_actor.navigation_grid = _grid
	_actor.position = position
	_actor.collision_layer = 1
	_actor.collision_mask = 1
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 12.0
	shape.shape = circle
	_actor.add_child(shape)
	_world.add_child(_actor)
	_queue = _actor.action_queue
	_queue.action_committed.connect(_on_committed)
	_queue.intent_finished.connect(_on_finished)
	_picker = WorldPicker.new()
	_world.add_child(_picker)
	_controller = InteractionController.new()
	_controller.setup(_actor, _picker)
	_world.add_child(_controller)
	await _frames(3)


func _dispose_fixture() -> void:
	for action_name in [&"move_left", &"move_right", &"move_up", &"move_down"]:
		Input.action_release(action_name)
	if is_instance_valid(_world):
		if is_instance_valid(_queue):
			_queue.cancel_action("Test cleanup")
		_world.queue_free()
		await process_frame
		await physics_frame
	_world = null
	_actor = null
	_grid = null
	_queue = null


func _target(kind: StringName, position: Vector2, hp: int = 3) -> Interactable:
	var item := Interactable.new()
	item.configure(kind, "Test " + String(kind), position, Color.WHITE, 22.0)
	item.object_hp = hp
	if kind == &"pickup":
		item.loot_item_id = &"scrap"
		item.loot_quantity = 2
	_world.add_child(item)
	return item


func _wall(rect: Rect2) -> StaticBody2D:
	_grid.set_solid_rect_world(rect, true)
	var body := StaticBody2D.new()
	body.position = rect.get_center()
	body.collision_layer = 1
	body.collision_mask = 1
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = rect.size
	shape.shape = rectangle
	body.add_child(shape)
	_world.add_child(body)
	return body


func _request(item: Interactable) -> void:
	_queue.request_action(item, ActionResolver.resolve(_actor, item))


func _count(item_id: StringName) -> int:
	return int(_actor.inventory.get(item_id, 0))


func _on_committed(token: int, action_id: StringName, result: Dictionary) -> void:
	_commits.append({
		"token": token, "action_id": String(action_id), "result": result.duplicate(true),
		"position": [_actor.global_position.x, _actor.global_position.y]
	})


func _on_finished(token: int, reason: String) -> void:
	_finishes.append({"token": token, "reason": reason})


func _commits_for(action_id: StringName) -> int:
	var total := 0
	for commit in _commits:
		if String(commit["action_id"]) == String(action_id):
			total += 1
	return total


func _check(condition: bool, description: String) -> void:
	_assertions.append({"passed": condition, "description": description})


func _frames(count: int) -> void:
	for _i in range(count):
		await physics_frame
	await process_frame


func _wait_until(predicate: Callable, timeout: float = 5.0) -> bool:
	var ticks := ceili(timeout * float(Engine.physics_ticks_per_second))
	for _i in range(ticks):
		if bool(predicate.call()):
			return true
		await physics_frame
	return bool(predicate.call())


func _idle() -> bool:
	return _queue.current_intent == null


func _windup() -> bool:
	return _queue.current_intent != null and _queue.current_intent.status == ActionIntent.Status.WINDUP


func _test_remote_chest() -> void:
	await _new_fixture()
	var chest := _target(&"chest", Vector2(480, 256))
	_request(chest)
	_check(_count(&"canned_food") == 0, "Clicking a distant chest awards nothing immediately")
	var completed := await _wait_until(func() -> bool: return chest.is_open and _idle())
	_check(completed, "Actor reaches and finishes opening chest within timeout")
	_check(_actor.global_position.distance_to(chest.global_position) <= chest.interaction_range + 1.0, "Open commits from actual interaction range")
	_check(_count(&"canned_food") == 2 and _commits_for(&"open") == 1, "One open grants exactly two food")
	_request(chest)
	await _wait_until(_idle)
	_check(_count(&"canned_food") == 2, "Re-interaction does not award the chest contents again")


func _test_repeat_chop() -> void:
	await _new_fixture()
	var tree := _target(&"tree", Vector2(166, 256), 3)
	var tree_id := tree.get_instance_id()
	_request(tree)
	var completed := await _wait_until(func() -> bool: return not is_instance_id_valid(tree_id) and _idle())
	_check(completed, "One request finishes all three chops")
	_check(_commits_for(&"chop") == 3, "Exactly three successful chop commits occur")
	_check(_count(&"wood") == 3, "Felling grants exactly three wood")
	var tokens: Array[int] = []
	for event in _commits:
		tokens.append(int(event["token"]))
	_check(tokens.size() == 3 and tokens[0] != tokens[1] and tokens[1] != tokens[2], "Each repeated action has its own token")


func _test_repeat_attack() -> void:
	await _new_fixture()
	var enemy := _target(&"zombie", Vector2(166, 256), 2)
	var enemy_id := enemy.get_instance_id()
	_request(enemy)
	var completed := await _wait_until(func() -> bool: return not is_instance_id_valid(enemy_id) and _idle())
	_check(completed, "A single attack request continues until enemy defeat")
	_check(_commits_for(&"attack") == 2 and _count(&"core_shard") == 1, "Two hits award one core shard, once")


func _test_pickup() -> void:
	await _new_fixture()
	var item := _target(&"pickup", Vector2(166, 256))
	var item_id := item.get_instance_id()
	_request(item)
	await _wait_until(func() -> bool: return not is_instance_id_valid(item_id) and _idle())
	await _frames(45)
	_check(not is_instance_valid(item), "Collected item is removed from scene")
	_check(_count(&"scrap") == 2 and _commits_for(&"pick_up") == 1, "Pickup grants exactly its configured amount once")


func _test_cancel_windup() -> void:
	await _new_fixture()
	var chest := _target(&"chest", Vector2(166, 256))
	_request(chest)
	var entered := await _wait_until(_windup)
	_check(entered, "Action reaches WINDUP before commit")
	_check(_count(&"canned_food") == 0, "No inventory change at windup entry")
	_queue.cancel_action("Regression: cancelled before commit")
	await _frames(60)
	_check(not chest.is_open and _count(&"canned_food") == 0, "Cancelled animation never opens chest or grants loot")
	_check(_commits.is_empty() and _idle() and _actor.path_finished(), "No delayed commit or lingering navigation survives cancellation")


func _test_cancel_recovery() -> void:
	await _new_fixture()
	var tree := _target(&"tree", Vector2(166, 256), 3)
	_request(tree)
	var landed := await _wait_until(func() -> bool: return _commits_for(&"chop") == 1)
	_check(landed, "First chop lands")
	_queue.cancel_action("Regression: cancel after commit")
	await _frames(90)
	_check(is_instance_valid(tree) and tree.object_hp == 2, "A landed hit is preserved and a second hit is not started")
	_check(_commits_for(&"chop") == 1 and _count(&"wood") == 0, "No repeat damage or felling loot after recovery cancellation")


func _test_duplicate_commit() -> void:
	await _new_fixture()
	var tree := _target(&"tree", Vector2(166, 256), 3)
	_request(tree)
	var landed := await _wait_until(func() -> bool: return _commits_for(&"chop") == 1)
	_check(landed, "Original animation commit lands")
	if landed:
		var token := int(_commits[0]["token"])
		_actor.animation_driver.commit_requested.emit(token)
		_actor.animation_driver.commit_requested.emit(token)
		_check(tree.object_hp == 2 and _commits_for(&"chop") == 1, "Duplicate same-token callbacks have no second effect")
	_queue.cancel_action("End duplicate token test")


func _test_stale_token() -> void:
	await _new_fixture()
	var first := _target(&"chest", Vector2(166, 256))
	var second := _target(&"chest", Vector2(128, 294))
	_request(first)
	await _wait_until(_windup)
	if _queue.current_intent == null:
		_check(false, "First action has a live token")
		return
	var old_token: int = _queue.current_intent.token
	_request(second)
	await _wait_until(_windup)
	_actor.animation_driver.commit_requested.emit(old_token)
	_check(not first.is_open and not second.is_open and _commits.is_empty(), "Late old callback cannot execute replacement action")
	await _wait_until(_idle)
	_check(not first.is_open and second.is_open and _count(&"canned_food") == 2, "Only current action's own animation earns loot")


func _test_replace_windup() -> void:
	await _new_fixture()
	var first := _target(&"chest", Vector2(166, 256))
	var second := _target(&"pickup", Vector2(128, 294))
	var second_id := second.get_instance_id()
	_request(first)
	await _wait_until(_windup)
	_request(second)
	await _wait_until(func() -> bool: return not is_instance_id_valid(second_id) and _idle())
	await _frames(30)
	_check(not first.is_open and _count(&"canned_food") == 0, "Replaced chest action never commits")
	_check(_count(&"scrap") == 2 and _commits_for(&"pick_up") == 1, "Replacement pickup finishes normally")


func _test_stale_equipment_request() -> void:
	await _new_fixture()
	var tree := _target(&"tree", Vector2(166, 256), 3)
	var cached := ActionResolver.resolve(_actor, tree)
	_check(StringName(cached.get("id", &"")) == &"chop", "Initial axe resolves to chop")
	_actor.equip_item(&"")
	_queue.request_action(tree, cached)
	await _frames(60)
	_check(tree.object_hp == 3 and _count(&"wood") == 0, "Stale cached chop cannot bypass equipment requirements")
	_check(_idle() and _commits_for(&"chop") == 0, "Invalid action ends without a commit")


func _test_equipment_during_approach() -> void:
	await _new_fixture()
	var tree := _target(&"tree", Vector2(600, 256), 3)
	_request(tree)
	await _frames(8)
	_actor.equip_item(&"")
	await _wait_until(_idle)
	await _frames(45)
	_check(tree.object_hp == 3 and _commits_for(&"chop") == 0, "Unequipping en route prevents the pending chop")
	_check(_idle() and _actor.path_finished(), "Invalid work does not leave the actor walking forever")


func _test_equipment_during_windup() -> void:
	await _new_fixture()
	var tree := _target(&"tree", Vector2(166, 256), 3)
	_request(tree)
	await _wait_until(_windup)
	_actor.equip_item(&"")
	await _frames(75)
	_check(tree.object_hp == 3 and _commits_for(&"chop") == 0, "Unequipping during windup invalidates the strike before its event")
	_check(_idle(), "Invalidated strike reaches a terminal state")


func _test_wall_occlusion() -> void:
	await _new_fixture(Vector2(160, 256))
	_wall(Rect2(184, 192, 8, 128))
	var chest := _target(&"chest", Vector2(224, 256))
	chest.interaction_range = 90.0
	await _frames(3)
	_check(not _grid.has_interaction_line(_actor.global_position, chest.global_position), "Fixture starts close but separated by solid wall")
	_request(chest)
	await _frames(15)
	_check(not chest.is_open, "Being within nominal range does not permit opening through wall")
	var completed := await _wait_until(func() -> bool: return chest.is_open and _idle(), 8.0)
	_check(completed, "Actor can still go around wall and open the chest")
	if not _commits.is_empty():
		var position: Array = _commits[0]["position"]
		_check(_grid.has_interaction_line(Vector2(float(position[0]), float(position[1])), chest.global_position), "Effect commits only from unobstructed position")
	_check(_count(&"canned_food") == 2, "Occlusion correction never duplicates loot")


func _test_unreachable() -> void:
	await _new_fixture(Vector2(128, 256))
	_wall(Rect2(300, 0, 32, 736))
	var chest := _target(&"chest", Vector2(480, 256))
	await _frames(3)
	_request(chest)
	var stopped := await _wait_until(_idle, 2.0)
	_check(stopped and _actor.path_finished(), "Fully separated target terminates within two seconds")
	_check(not chest.is_open and _count(&"canned_food") == 0 and _commits.is_empty(), "Unreachable failure never awards loot")
	_check(not _finishes.is_empty(), "Failure has a terminal event for UI and telemetry")


func _test_moving_target() -> void:
	await _new_fixture()
	var chest := _target(&"chest", Vector2(600, 256))
	_request(chest)
	await _frames(12)
	chest.global_position = Vector2(850, 448)
	var completed := await _wait_until(func() -> bool: return chest.is_open and _idle(), 10.0)
	_check(completed, "Request follows relocated target instead of interacting at stale coordinates")
	_check(_actor.global_position.distance_to(chest.global_position) <= chest.interaction_range + 1.0, "Final interaction uses target's latest position")
	_check(_count(&"canned_food") == 2, "Replanning grants loot once")


func _test_target_moves_during_windup() -> void:
	await _new_fixture()
	var chest := _target(&"chest", Vector2(166, 256))
	_request(chest)
	await _wait_until(_windup)
	chest.global_position = Vector2(700, 256)
	await _frames(25)
	_check(not chest.is_open and _count(&"canned_food") == 0, "Windup event cannot affect a target now outside range")
	var completed := await _wait_until(func() -> bool: return chest.is_open and _idle(), 8.0)
	_check(completed and _count(&"canned_food") == 2, "Action re-approaches and commits normally at the new position")


func _test_target_deleted_approach() -> void:
	await _new_fixture()
	var chest := _target(&"chest", Vector2(600, 256))
	_request(chest)
	await _frames(6)
	chest.queue_free()
	var stopped := await _wait_until(_idle, 1.0)
	await _frames(30)
	_check(stopped and _actor.path_finished(), "Deleting a target ends its pending navigation")
	_check(_count(&"canned_food") == 0 and _commits.is_empty(), "A removed target cannot leave a delayed reward")


func _test_target_deleted_windup() -> void:
	await _new_fixture()
	var chest := _target(&"chest", Vector2(166, 256))
	_request(chest)
	await _wait_until(_windup)
	chest.queue_free()
	await _frames(60)
	_check(_idle() and _count(&"canned_food") == 0 and _commits.is_empty(), "Target deletion during animation is safe and has no effect")


func _test_manual_cancel() -> void:
	await _new_fixture()
	var chest := _target(&"chest", Vector2(600, 256))
	_request(chest)
	await _frames(6)
	var before := _actor.global_position
	Input.action_press(&"move_down")
	await _frames(10)
	Input.action_release(&"move_down")
	await _frames(30)
	_check(_actor.global_position.y > before.y + 10.0, "Manual input actually moves actor")
	_check(_idle() and _actor.path_finished(), "Manual movement cancels buffered intent and automatic path")
	_check(not chest.is_open and _count(&"canned_food") == 0, "Cancelled work does not finish in background")


func _test_right_click_cancel() -> void:
	await _new_fixture()
	var chest := _target(&"chest", Vector2(600, 256))
	_request(chest)
	await _frames(6)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_RIGHT
	click.pressed = true
	click.position = Vector2(900, 600)
	root.push_input(click, true)
	await _frames(3)
	var stopped_position := _actor.global_position
	await _frames(20)
	_check(_idle() and _actor.path_finished(), "Viewport right-click reaches controller cancellation")
	_check(_actor.global_position.distance_to(stopped_position) < 1.0, "Actor remains stopped after cancellation")
	_check(_count(&"canned_food") == 0, "Right-click does not cause a queued effect")


func _test_picker_overlap() -> void:
	await _new_fixture()
	var back := _target(&"chest", Vector2(300, 300))
	var front := _target(&"pickup", Vector2(300, 310))
	await _frames(3)
	_check(_picker.pick_target(Vector2(300, 305)) == front, "Picker chooses visually frontmost overlapping target")
	front.queue_free()
	_check(_picker.pick_target(Vector2(300, 305)) == back, "Queued-for-deletion target cannot steal a pick")


func _test_navigation_clearance() -> void:
	await _new_fixture(Vector2(160, 300))
	var rect := Rect2(300, 192, 80, 224)
	_wall(rect)
	await _frames(3)
	var destination := Vector2(560, 300)
	_check(_actor.move_to_position(destination), "Navigation can route around test wall")
	var entered_obstacle := false
	var reached := false
	for _i in range(540):
		await physics_frame
		if rect.grow(11.5).has_point(_actor.global_position):
			entered_obstacle = true
		if _actor.path_finished():
			reached = true
			break
	_check(not entered_obstacle, "Player collision radius never clips the solid wall")
	_check(reached and _actor.global_position.distance_to(destination) <= 9.0, "Actor reaches requested destination without stuck path")


func _test_dynamic_obstacle() -> void:
	await _new_fixture()
	var chest := _target(&"chest", Vector2(600, 256))
	_request(chest)
	await _frames(6)
	_wall(Rect2(300, 0, 32, 736))
	var stopped := await _wait_until(_idle, 4.0)
	_check(stopped and _actor.path_finished(), "Dynamically sealed route stops instead of walking forever")
	_check(_actor.global_position.x < 300.0 - 11.5, "Actor never crosses newly closed solid wall")
	_check(not chest.is_open and _count(&"canned_food") == 0, "Obsolete route cannot commit the target effect")


func _test_missing_animation_event() -> void:
	await _new_fixture()
	var chest := _target(&"chest", Vector2(166, 256))
	_request(chest)
	var entered := await _wait_until(_windup)
	_check(entered, "Animation enters windup before simulating a broken art adapter")
	_actor.animation_driver.cancel_action()
	var stopped := await _wait_until(_idle, 3.0)
	_check(stopped and not _finishes.is_empty(), "Missing animation events trigger a bounded terminal failure")
	_check(not chest.is_open and _count(&"canned_food") == 0 and _commits.is_empty(), "Watchdog never fabricates a commit to compensate for absent events")


func _test_completion_callback_reentry() -> void:
	await _new_fixture()
	var tree := _target(&"tree", Vector2(166, 256), 3)
	var chest := _target(&"chest", Vector2(128, 294))
	var state := {"switched": false}
	_queue.intent_finished.connect(func(_token: int, reason: String) -> void:
		if reason == "completed" and not bool(state["switched"]):
			state["switched"] = true
			_request(chest)
	)
	_request(tree)
	var completed := await _wait_until(func() -> bool: return chest.is_open and _idle())
	_check(bool(state["switched"]) and completed, "Completion listener can issue and finish a new chest command")
	_check(is_instance_valid(tree) and tree.object_hp == 2, "Old automatic chopping never resumes over the callback command")
	_check(_commits_for(&"chop") == 1 and _commits_for(&"open") == 1, "One old strike and one replacement open commit")
	_check(_count(&"wood") == 0 and _count(&"canned_food") == 2, "Only actually completed work awards its own loot")


func _test_inventory_callback_reentry() -> void:
	await _new_fixture()
	_queue.repeat_enabled = false
	var chest := _target(&"chest", Vector2(166, 256))
	var enemy := _target(&"zombie", Vector2(128, 294), 2)
	var state := {"switched": false, "replacement_token": -1}
	_actor.inventory_changed.connect(func() -> void:
		if _count(&"canned_food") == 2 and not bool(state["switched"]):
			state["switched"] = true
			_request(enemy)
			if _queue.current_intent != null:
				state["replacement_token"] = _queue.current_intent.token
	)
	_request(chest)
	var switched := await _wait_until(func() -> bool: return bool(state["switched"]))
	_check(switched and chest.is_open and _count(&"canned_food") == 2, "Inventory callback runs inside a successful chest effect")
	_check(_queue.current_intent != null and _queue.current_intent.token == int(state["replacement_token"]) and not _queue.current_intent.committed, "Returning from old execute_action leaves replacement uncommitted")
	_check(is_instance_valid(enemy) and enemy.object_hp == 2, "Replacement strike does not inherit the old chest's commit event")
	var completed := await _wait_until(_idle)
	_check(completed and is_instance_valid(enemy) and enemy.object_hp == 1, "Replacement commits once at its own animation event")
	_check(_commits_for(&"open") == 1 and _commits_for(&"attack") == 1 and _count(&"core_shard") == 0, "Both actions report their own effects without phantom damage or reward")


func _test_reapproach_callback_reentry() -> void:
	await _new_fixture()
	var moved_chest := _target(&"chest", Vector2(166, 256))
	var replacement := _target(&"chest", Vector2(128, 294))
	var state := {"switched": false}
	_queue.intent_finished.connect(func(_token: int, reason: String) -> void:
		if reason == "reapproach" and not bool(state["switched"]):
			state["switched"] = true
			_request(replacement)
	)
	_request(moved_chest)
	await _wait_until(_windup)
	moved_chest.global_position = Vector2(700, 256)
	var completed := await _wait_until(func() -> bool: return replacement.is_open and _idle())
	_check(bool(state["switched"]) and completed, "Reapproach notification listener can replace the old command")
	_check(not moved_chest.is_open and _actor.global_position.distance_to(Vector2(128, 256)) < 5.0, "Old reapproach path never restarts over the replacement command")
	_check(_count(&"canned_food") == 2 and _commits_for(&"open") == 1, "Only replacement target supplies a single reward")


func _start_mission() -> void:
	await _dispose_fixture()
	_commits = []
	_finishes = []
	_world = load("res://scenes/supply_run.tscn").instantiate()
	root.add_child(_world)
	_grid = _world.navigation_grid
	_actor = _world.player
	_queue = _actor.action_queue
	_controller = _world.interaction
	_picker = _controller.world_picker
	_queue.action_committed.connect(_on_committed)
	_queue.intent_finished.connect(_on_finished)
	await _frames(3)


func _test_field_search() -> void:
	await _start_mission()
	var item: Interactable = _world.salvage
	var skill: FieldSearch = _world.field_search
	_check(_picker.pick_target(item.position) == null and ActionResolver.resolve(_actor, item).is_empty(), "Hidden salvage cannot be picked or commanded")
	_check(skill.use() and not item.visible and _count(&"scrap") == 0, "Initial scan out of range reveals and awards nothing")
	_check(not skill.use() and skill.seconds_left() == 3, "Immediate repeat is blocked by the three-second cooldown")
	_actor.position = Vector2(481,364)
	await _wait_until(func() -> bool: return skill.seconds_left() == 0, 4)
	_check(skill.use() and not item.visible, "Car body blocks a scan from the wrong side")
	_actor.position = Vector2(452,438)
	await _wait_until(func() -> bool: return skill.seconds_left() == 0, 4)
	_check(skill.use() and item.visible and _world.wreck.is_open, "Unobstructed scan reveals the salvage and marks the wreck searched")
	_check(_picker.pick_target(item.position) == item and _count(&"scrap") == 0, "Revealed target becomes pickable without automatically awarding loot")
	_request(item)
	await _wait_until(_idle)
	_check(_count(&"scrap") == 2 and _commits_for(&"pick_up") == 1, "One pickup yields exactly two units")


func _test_wreck_click() -> void:
	await _start_mission()
	var wreck: SupplyFixture = _world.wreck
	var picked := _picker.pick_target(Vector2(481,393))
	_check(picked == wreck and _grid.is_walkable_world(wreck.position), "Visible car resolves to a clear interaction point")
	if picked == null:
		return
	_request(picked)
	await _wait_until(_idle, 6)
	_check(_commits_for(&"survey_site") == 1 and _world.salvage.visible, "Clicking the car walks to its rear and triggers the shared search skill")
	_check(not _world.field_search.use() and _count(&"scrap") == 0, "Keyboard search shares cooldown and loot still needs a pickup")


func _test_repair_interrupt() -> void:
	await _start_mission()
	var post: SupplyFixture = _world.bridge
	_actor.position = post.position - Vector2(36,0)
	_actor.add_item(&"wood", 3)
	_check(ActionResolver.resolve_id(_actor, post, &"repair_bridge").is_empty() and not post.execute_action(&"repair_bridge",_actor).success, "Missing metal rejects a direct and a queued repair")
	_check(_count(&"wood") == 3 and not post.is_open, "Rejected repair charges nothing")
	_actor.add_item(&"scrap",2)
	_request(post)
	await _wait_until(_windup)
	_queue.cancel_action("manual cancel")
	await _frames(45)
	_check(_count(&"wood") == 3 and _count(&"scrap") == 2 and not post.is_open, "Cancelling before impact retains both stacks and the physical barrier")
	_request(post)
	await _wait_until(_windup)
	_actor.spend_items({&"scrap":1})
	await _wait_until(_idle)
	_check(_count(&"wood") == 3 and _count(&"scrap") == 1 and not post.is_open and _commits_for(&"repair_bridge") == 0, "External spending during windup prevents repair without partial payment")


func _test_repair_atomic() -> void:
	await _start_mission()
	var post: SupplyFixture = _world.bridge
	_actor.position = post.position - Vector2(36,0)
	_actor.add_item(&"wood",4)
	_actor.add_item(&"scrap",3)
	var seen: Array[Array] = []
	_actor.inventory_changed.connect(func() -> void:
		seen.append([_count(&"wood"), _count(&"scrap"), post.is_open, _grid.has_movement_line(Vector2(1034,588),Vector2(1098,588))])
		_queue.cancel_action("inventory listener")
	)
	_request(post)
	await _wait_until(func() -> bool: return post.is_open)
	await _frames(3)
	_check(seen.size() == 1 and seen[0] == [1,1,true,true], "Listener sees one coherent payment and a repaired fixture")
	_check(_commits_for(&"repair_bridge") == 1 and _idle() and _world._gate_shape.disabled, "Callback cancellation still records one commit and unblocks physical traversal")
	_check(not post.execute_action(&"repair_bridge", _actor).success and _count(&"wood") == 1 and _count(&"scrap") == 1, "Repeat attempt cannot consume surplus resources")


func _test_supply_run() -> void:
	await _start_mission()
	var depot: SupplyFixture = _world.depot
	var bridge: SupplyFixture = _world.bridge
	var infirmary: SupplyFixture = _world.infirmary
	var tree := _picker.pick_target(Vector2(786,257))
	_check(_grid.find_approach_path(_actor.position,depot.position,52).is_empty() and not depot.execute_action(&"take_kit",_actor).success, "Depot is physically unreachable and rejects a premature reward")
	_check(not infirmary.execute_action(&"deliver_kit",_actor).success, "Duty desk rejects an empty handover")
	_request(tree)
	await _wait_until(_idle, 9)
	_check(_count(&"wood") == 3, "Starting from the west, the actor reaches and chops the northern tree")
	_request(_world.wreck)
	await _wait_until(_idle, 8)
	_request(_world.salvage)
	await _wait_until(_idle)
	_check(_count(&"scrap") == 2, "Car search and pickup also work after chopping first")
	_request(bridge)
	await _wait_until(_idle, 9)
	_check(bridge.is_open and _world._gate_shape.disabled and _count(&"wood") == 0 and _count(&"scrap") == 0, "Repair pays both costs and removes the physical gate")
	_check(_grid.has_movement_line(Vector2(1034,588),Vector2(1098,588)) and not _grid.has_movement_line(Vector2(1034,540),Vector2(1098,540)), "Only the repaired plank crossing opens")
	_request(depot)
	await _wait_until(_idle, 6)
	_check(depot.is_open and _actor.position.x > 1075 and _count(&"medical_kit") == 1, "Actor walks across the bridge to collect the kit")
	_request(depot)
	await _wait_until(_idle)
	_check(_count(&"medical_kit") == 1 and _commits_for(&"take_kit") == 1, "Reopening the box cannot duplicate the kit")
	_request(infirmary)
	await _wait_until(_idle, 12)
	_check(infirmary.is_open and _count(&"medical_kit") == 0 and _world.goal_title.text == "值班员已签收", "Walk back through the actual map and deliver the kit to complete the HUD objective")
	_request(infirmary)
	await _wait_until(_idle)
	_check(_commits_for(&"deliver_kit") == 1, "Repeated handover cannot complete the mission twice")
	await _start_mission()
	_check(not _world.bridge.is_open and not _world.depot.is_open and not _world.infirmary.is_open and not _world.salvage.visible and _world.field_search.seconds_left() == 0, "A fresh run resets all mission progress and the search cooldown")


func _test_night_budget() -> void:
	var night := NightRun.new()
	night.buy(&"bar")
	_check(night.money == 3 and night.purchases[&"bar"] == 1, "Buying a bar charges exactly seven vouchers")
	night.buy(&"blanket")
	_check(night.money == 3 and night.purchases[&"blanket"] == 0, "Over-budget purchase is rejected without mutation")
	night.refund(&"bar")
	night.refund(&"bar")
	_check(night.money == 10, "Refunding an empty slot cannot generate credit")
	night.buy(&"drink")
	night.buy(&"drink")
	night.buy(&"drink")
	_check(night.money == 4 and night.purchases[&"drink"] == 2, "Drink limit preserves the balance")
	night.begin_night()
	night.refund(&"drink")
	night.buy(&"drink")
	_check(night.drinks_left == 2 and night.money == 4 and night.purchases[&"drink"] == 2, "Sealed manifest carries the purchases into the night")
	_check(night.drink() and night.drink() and not night.drink() and night.hunger == 0, "Only carried meals can be consumed and hunger stops at zero")


func _night_combo(tool: StringName) -> NightRun:
	var night := NightRun.new()
	night.buy(tool)
	night.buy(&"drink")
	night.begin_night()
	return night


func _test_night_sense() -> void:
	var plain := _night_combo(&"bar")
	var echo := _night_combo(&"bar")
	_check(plain.manifest() == echo.manifest() and plain.money == echo.money, "Two runs start with the same stock and balance")
	_check(echo.sense() and not echo.sense() and echo.sanity == 40, "Only the first use reveals the source and charges SAN")
	_check(plain.search(&"booth") and echo.search(&"pump"), "Player chooses the near booth blind or the locked pump after the reveal")
	_check(not plain.sense() and not echo.search(&"booth"), "A completed trip closes scouting and additional looting")
	plain.settle()
	echo.settle()
	_check(plain.wetness == 70 and echo.wetness == 50 and plain.fuel == 1 and echo.fuel == 3, "Near uncovered street and three-fuel distant pump produce different drying")
	_check(not echo.settle() and not echo.drink() and not plain.used_sense, "Report is terminal and the control run records zero uses")
	var blind_pump := _night_combo(&"bar")
	_check(blind_pump.search(&"pump") and blind_pump.fuel == 3, "Sense reveals information; identical loot is still present when skipped")


func _test_night_loadouts() -> void:
	var warm := _night_combo(&"blanket")
	var bar := _night_combo(&"bar")
	warm.search(&"booth")
	bar.search(&"booth")
	warm.settle()
	bar.settle()
	_check(warm.wetness == 30 and bar.wetness == 70 and warm.health == 40 and bar.health == 20 and warm.fuel == bar.fuel, "Same route and no sense isolate the effect of the blanket")
	var untooled := _night_combo(&"blanket")
	untooled.search(&"pump")
	_check(untooled.fuel == 1 and untooled.wetness == 60, "Without a bar the locked cabinet stays shut; the rain blanket keeps off part of the rain")
	var bare := NightRun.new()
	bare.begin_night()
	_check(bare.settle() and bare.route == &"stay" and bare.health == 40 and bare.wetness == 70, "With no supplies the leaking shelter costs twenty health")
	_check(NightRun.new().phase == NightRun.Phase.SHOP and not NightRun.new().used_sense, "A new run starts in the shop with a fresh ability")


func _open_first_night() -> void:
	await _dispose_fixture()
	_world = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(_world)
	_actor = _world.player
	_queue = _actor.action_queue
	_controller = _world.interaction
	_picker = _controller.world_picker
	await _frames(3)


func _test_night_scene() -> void:
	await _open_first_night()
	_check(_world.shopping.visible and not _world.sites[&"pump"].interaction_enabled, "Default launch presents procurement and isolates world input")
	var projected: Vector2 = _world.street.camera.unproject_position(NightStreet.ground(_actor.position))
	_check(projected.distance_to(_actor.position) < 0.5, "3D camera projects the logic-plane foot point to the same click coordinate")
	_world._buy(&"bar")
	_world._buy(&"drink")
	_world._begin()
	_world._sense()
	_world._sense()
	_check(_world.street.traces[0].visible and _world.sense_button.disabled and _world.run.sanity == 40, "Scene displays the clue, charges once and disables repeated use")
	var pump: FirstNightSite = _world.sites[&"pump"]
	_check(_picker.pick_target(pump.position-Vector2(0,44)) == pump, "Clicking the visible facade resolves its exterior approach point")
	_request(pump)
	await _frames(8)
	_queue.cancel_action("test")
	_check(_world.run.route.is_empty() and _world.run.fuel == 0 and _world.run.hunger == 50 and _world.run.wetness == 35, "Cancelling approach consumes neither the trip nor its reward")
	_request(pump)
	await _wait_until(_idle,12)
	_check(_world.run.route == &"pump" and _world.run.fuel == 3, "Actor reaches the pump by normal movement and obtains the loadout reward")
	_request(_world.sites[&"shelter"])
	await _wait_until(_idle,12)
	_check(_world.report.visible and _world.run.health == 20 and _world.vital_values[0].text == "20" and _world.report_text.text.contains("感知 1 次"), "Actual home interaction opens the completed settlement comparison")


func _test_night_meal() -> void:
	var empty := NightRun.new()
	empty.begin_night()
	empty.sense()
	empty.search(&"pump")
	empty.settle()
	_check(empty.health == 0 and empty.hunger == 90 and empty.wetness == 90 and empty.sanity == 10, "Unprepared distant trip can exhaust health through all three pressures")
	var packed := _night_combo(&"bar")
	packed.sense()
	packed.search(&"pump")
	_check(packed.drink() and packed.hunger == 40, "Eating after the round trip still reduces hunger before shelter settlement")
	packed.settle()
	_check(packed.health == 60 and packed.hunger == 60 and packed.wetness == 50 and packed.sanity == 30, "Food and a full cabinet protect health even after listening to the echo")
	_check(not packed.drink() and not packed.search(&"booth") and not packed.sense() and not packed.settle(), "Dawn closes all four night actions")
	_check(NightRun.new().health == 60 and NightRun.new().hunger == 50 and NightRun.new().wetness == 35 and NightRun.new().sanity == 60, "A fresh run restores every vital")


func _test_night_thresholds() -> void:
	for offset in [0, -1]:
		var night := NightRun.new()
		night.begin_night()
		night.hunger = 60 + offset
		night.wetness = 30 + offset
		night.sanity = 55 if offset == 0 else 36
		night.settle()
		_check(night.health == (0 if offset == 0 else 60), "Threshold equality and the nearest safe values give different health outcomes")
	var capped := NightRun.new()
	capped.begin_night()
	capped.health = 7
	capped.hunger = 95
	capped.wetness = 95
	capped.sanity = 8
	capped.sense()
	capped.search(&"pump")
	capped.settle()
	_check(capped.hunger == 100 and capped.wetness == 100 and capped.sanity == 0 and capped.health == 0, "All four values stay inside 0 to 100 across actions and settlement")

func _press_camera_key(key: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = true
	root.push_input(event, true)
	event.pressed = false
	root.push_input(event, true)


func _mouse_click(button: MouseButton, at: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.position = at
	event.pressed = true
	root.push_input(event, true)
	event.pressed = false
	root.push_input(event, true)


func _test_camera_controls() -> void:
	await _open_first_night()
	_press_camera_key(KEY_E)
	_mouse_click(MOUSE_BUTTON_WHEEL_UP, Vector2(100, 350))
	var street: NightStreet = _world.street
	_check(street.view_index == 0 and street.zoom_index == 3, "The shop does not consume street camera controls")
	_world._begin()
	# Stand on open pavement so every roof remains within the viewport at wide zoom.
	_actor.position = Vector2(640, 480)
	for i in range(10):
		_mouse_click(MOUSE_BUTTON_WHEEL_DOWN, Vector2(640, 360))
	await _frames(40)
	_check(is_equal_approx(street.zoom_factor, 0.55), "Wheel down stops at the far limit")
	for i in range(4):
		_press_camera_key(KEY_E)
		await _frames(22)
		var expected_view := (i + 1) % 4
		_check(street.view_index == expected_view and is_equal_approx(street.yaw, (i + 1) * PI / 2.0), "E advances and wraps a real 90 degree camera pose (%d)" % i)
		var pump: FirstNightSite = _world.sites[&"pump"]
		var roof_pixel := street.camera.unproject_position(NightStreet.ground(NightStreet.BUILDINGS[&"pump"].get_center(), 2.6))
		_mouse_click(MOUSE_BUTTON_LEFT, roof_pixel)
		_check(_queue.current_intent != null and _queue.current_intent.target == pump, "Viewport click on the rendered pump roof selects its exterior work point (%d)" % i)
		_mouse_click(MOUSE_BUTTON_RIGHT, roof_pixel)
		var dest := _actor.position + Vector2(70, 18)
		var projected := street.camera.unproject_position(NightStreet.ground(dest))
		_mouse_click(MOUSE_BUTTON_LEFT, projected)
		var path := _actor.path_preview()
		_check(path.size() > 1 and path[-1].distance_to(dest) < 25, "Ground click and the camera agree on the navigation destination (%d)" % i)
		_mouse_click(MOUSE_BUTTON_RIGHT, projected)
		Input.action_press("move_right")
		var start := _actor.position
		await _frames(6)
		Input.action_release("move_right")
		var displacement := street.ground_transform.basis_xform(_actor.position - start)
		_check(displacement.x > 1.0 and absf(displacement.y) < 0.1, "D moves toward screen right for this view (%d)" % i)
		_actor.position = Vector2(640, 480)
	_check(_world.run.sanity == 60 and not _world.run.used_sense, "Rotating does not spend SAN or use the player's sense")
	_press_camera_key(KEY_Q)
	_press_camera_key(KEY_Q)
	_press_camera_key(KEY_E)
	for i in range(12):
		_mouse_click(MOUSE_BUTTON_WHEEL_UP, Vector2(600, 360))
	await _frames(50)
	_check(street.view_index == 3 and is_equal_approx(street.zoom_factor, 1.75), "Rapid opposite turns and wheel up settle at the requested angle and near limit")
	_check(street.camera.unproject_position(NightStreet.ground(_actor.position)).distance_to(NightStreet.MAP_CENTER) < 0.5, "The player stays at the orbit pivot at full zoom")
	_press_camera_key(KEY_F)
	_check(_world.run.sanity == 40 and _world.run.used_sense, "F triggers the existing sense action once")
	await _dispose_fixture()
	_check(root.canvas_transform.is_equal_approx(Transform2D.IDENTITY), "Leaving the street restores the legacy scenes' canvas")
