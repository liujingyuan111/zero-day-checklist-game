class_name NavigationGrid
extends Node2D

## Navigation reserves actor radius plus margin; interaction uses original walls.
@export var grid_size: Vector2i = Vector2i(40, 23)
@export var cell_size: Vector2 = Vector2(32.0, 32.0)
@export var world_origin: Vector2 = Vector2.ZERO
@export var actor_radius: float = 12.0
@export var clearance_margin: float = 2.0

var last_failure_reason: String = ""
var revision: int = 0
var _astar: AStarGrid2D = AStarGrid2D.new()
var _wall_rects: Array[Rect2] = []
var _manual_solid_cells: Dictionary = {}


func _ready() -> void:
	configure(grid_size, cell_size, world_origin)


func configure(size: Vector2i, cell: Vector2, origin: Vector2) -> void:
	grid_size = Vector2i(maxi(size.x, 1), maxi(size.y, 1))
	cell_size = Vector2(maxf(cell.x, 1.0), maxf(cell.y, 1.0))
	world_origin = origin
	_astar.region = Rect2i(Vector2i.ZERO, grid_size)
	_astar.cell_size = cell_size
	_astar.offset = world_origin + cell_size * 0.5
	_astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.update()
	_rebuild_solids()


func set_solid_rect_world(rect: Rect2, solid: bool = true) -> void:
	var normalized := rect.abs()
	if normalized.size.x <= 0.0 or normalized.size.y <= 0.0:
		return
	var index := _wall_rects.find(normalized)
	if solid and index < 0:
		_wall_rects.append(normalized)
	elif not solid and index >= 0:
		_wall_rects.remove_at(index)
	else:
		return
	_rebuild_solids()


func set_solid_cell(cell: Vector2i, solid: bool = true) -> void:
	if not _inside(cell):
		return
	if solid:
		_manual_solid_cells[cell] = true
	else:
		_manual_solid_cells.erase(cell)
	_rebuild_solids()


func world_to_cell(world_position: Vector2) -> Vector2i:
	return Vector2i(
		floori((world_position.x - world_origin.x) / cell_size.x),
		floori((world_position.y - world_origin.y) / cell_size.y)
	)


func cell_to_world(cell: Vector2i) -> Vector2:
	return world_origin + (Vector2(cell) + Vector2(0.5, 0.5)) * cell_size


func is_walkable_world(world_position: Vector2) -> bool:
	if not world_position.is_finite():
		return false
	var clearance := actor_radius + clearance_margin
	if not _world_bounds().grow(-clearance).has_point(world_position):
		return false
	for wall in _all_walls():
		if _point_in_rect(world_position, wall.grow(clearance)):
			return false
	return true


func has_interaction_line(from: Vector2, to: Vector2) -> bool:
	if not from.is_finite() or not to.is_finite():
		return false
	for wall in _all_walls():
		if _segment_hits_rect(from, to, wall):
			return false
	return true


func has_movement_line(from: Vector2, to: Vector2) -> bool:
	return _movement_line_clear(from, to, false)


func find_path(start_world: Vector2, end_world: Vector2) -> PackedVector2Array:
	last_failure_reason = ""
	if not start_world.is_finite() or not end_world.is_finite():
		return _path_failure("Navigation position is invalid.")
	if not _world_bounds().has_point(start_world) or not _world_bounds().has_point(end_world):
		return _path_failure("Destination is outside the navigation area.")
	if not is_walkable_world(end_world):
		return _path_failure("Destination is blocked or too close to a wall.")
	# Manual collision may leave the actor in the 2px navigation safety margin.
	# An escape from that margin is allowed, but crossing the physical wall is not.
	if _movement_line_clear(start_world, end_world, true):
		return PackedVector2Array([start_world, end_world])
	var start_cell := _visible_connector(start_world, true)
	var end_cell := _visible_connector(end_world, false)
	if start_cell.x < 0 or end_cell.x < 0:
		return _path_failure("No clear connection to the navigation grid.")
	var ids := _astar.get_id_path(start_cell, end_cell, false)
	if ids.is_empty():
		return _path_failure("No route reaches the requested destination.")
	var result := PackedVector2Array([start_world])
	for id in ids:
		var point := cell_to_world(id)
		if result[result.size() - 1].distance_squared_to(point) > 0.01:
			result.append(point)
	if result[result.size() - 1].distance_squared_to(end_world) > 0.01:
		result.append(end_world)
	for i in range(1, result.size()):
		if not _movement_line_clear(result[i - 1], result[i], i == 1):
			return _path_failure("The route does not have enough clearance.")
	# Return the actual requested endpoint, never a silent nearest-cell substitute.
	return _smooth_path(result)


func find_approach_path(start_world: Vector2, target_world: Vector2, interaction_range: float) -> PackedVector2Array:
	last_failure_reason = ""
	if interaction_range <= 0.0 or not target_world.is_finite():
		return _path_failure("Interaction range or target is invalid.")
	if start_world.distance_to(target_world) <= interaction_range and has_interaction_line(start_world, target_world):
		return PackedVector2Array([start_world])
	var candidates: Array[Vector2] = []
	for fraction in [0.90, 0.62]:
		var radius: float = interaction_range * fraction
		for i in range(16):
			var angle := TAU * float(i) / 16.0
			candidates.append(target_world + Vector2(cos(angle), sin(angle)) * radius)
	# Centers supplement ring samples for corridors and corners.
	var first := world_to_cell(target_world - Vector2.ONE * interaction_range)
	var last := world_to_cell(target_world + Vector2.ONE * interaction_range)
	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			var candidate := cell_to_world(Vector2i(x, y))
			if candidate.distance_to(target_world) <= interaction_range:
				candidates.append(candidate)
	var best_path := PackedVector2Array()
	var best_cost := INF
	for candidate in candidates:
		if not is_walkable_world(candidate) or not has_interaction_line(candidate, target_world):
			continue
		if start_world.distance_to(candidate) >= best_cost:
			continue
		var path := find_path(start_world, candidate)
		if path.is_empty():
			continue
		var cost := _path_length(path)
		if cost < best_cost:
			best_cost = cost
			best_path = path
	if best_path.is_empty():
		return _path_failure("No reachable, unobstructed interaction position.")
	last_failure_reason = ""
	return best_path


func _visible_connector(position_world: Vector2, allow_start_margin: bool) -> Vector2i:
	var center := world_to_cell(position_world)
	var best := Vector2i(-1, -1)
	var best_distance := INF
	for y in range(center.y - 3, center.y + 4):
		for x in range(center.x - 3, center.x + 4):
			var cell := Vector2i(x, y)
			if _is_solid(cell):
				continue
			var world := cell_to_world(cell)
			var distance := position_world.distance_squared_to(world)
			if distance >= best_distance:
				continue
			if _movement_line_clear(position_world, world, allow_start_margin):
				best = cell
				best_distance = distance
	return best


func _rebuild_solids() -> void:
	var walls := _all_walls()
	var clearance := actor_radius + clearance_margin
	var usable_bounds := _world_bounds().grow(-clearance)
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			var cell := Vector2i(x, y)
			var cell_rect := Rect2(world_origin + Vector2(cell) * cell_size, cell_size)
			var blocked := not usable_bounds.has_point(cell_to_world(cell))
			for wall in walls:
				if cell_rect.intersects(wall.grow(clearance), true):
					blocked = true
					break
			_astar.set_point_solid(cell, blocked)
	revision += 1


func _all_walls() -> Array[Rect2]:
	var result: Array[Rect2] = _wall_rects.duplicate()
	for cell: Vector2i in _manual_solid_cells:
		result.append(Rect2(world_origin + Vector2(cell) * cell_size, cell_size))
	return result


func _movement_line_clear(from: Vector2, to: Vector2, allow_start_margin: bool) -> bool:
	if not from.is_finite() or not to.is_finite():
		return false
	var bounds := _world_bounds().grow(-actor_radius)
	if not bounds.has_point(from) or not bounds.has_point(to):
		return false
	for wall in _all_walls():
		var padded := wall.grow(actor_radius + clearance_margin)
		if not _segment_hits_rect(from, to, padded):
			continue
		if allow_start_margin and _point_in_rect(from, padded):
			if not _segment_hits_rect(from, to, wall.grow(actor_radius - 0.01)):
				continue
		return false
	return true


func _smooth_path(path: PackedVector2Array) -> PackedVector2Array:
	if path.size() <= 2:
		return path
	var result := PackedVector2Array([path[0]])
	var index := 0
	while index < path.size() - 1:
		var next := index + 1
		for candidate in range(path.size() - 1, index + 1, -1):
			if _movement_line_clear(path[index], path[candidate], index == 0):
				next = candidate
				break
		result.append(path[next])
		index = next
	return result


func _segment_hits_rect(from: Vector2, to: Vector2, rect: Rect2) -> bool:
	# Inclusive slab intersection: grazing the wall counts as obstruction.
	var delta := to - from
	var lower := 0.0
	var upper := 1.0
	for axis in range(2):
		if absf(delta[axis]) < 0.00001:
			if from[axis] < rect.position[axis] or from[axis] > rect.end[axis]:
				return false
			continue
		var first := (rect.position[axis] - from[axis]) / delta[axis]
		var last := (rect.end[axis] - from[axis]) / delta[axis]
		lower = maxf(lower, minf(first, last))
		upper = minf(upper, maxf(first, last))
		if lower > upper:
			return false
	return true


func _point_in_rect(point: Vector2, rect: Rect2) -> bool:
	return point.x >= rect.position.x and point.x <= rect.end.x and point.y >= rect.position.y and point.y <= rect.end.y


func _world_bounds() -> Rect2:
	return Rect2(world_origin, Vector2(grid_size) * cell_size)


func _inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < grid_size.x and cell.y < grid_size.y


func _is_solid(cell: Vector2i) -> bool:
	return not _inside(cell) or _astar.is_point_solid(cell)


func _path_failure(message: String) -> PackedVector2Array:
	last_failure_reason = message
	return PackedVector2Array()


func _path_length(path: PackedVector2Array) -> float:
	var total := 0.0
	for i in range(1, path.size()):
		total += path[i - 1].distance_to(path[i])
	return total
