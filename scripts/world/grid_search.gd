class_name GridSearch extends RefCounted
## Grid helpers shared by every placement policy: ring and block searches, flood fill,
## a seeded shuffle and the `[x, y]` pair encoding used by save sections. Stateless.


## Chebyshev (king-move) distance between two cells.
static func chebyshev(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


## Cells at Chebyshev distance `r` from `center` (just `center` when r is 0).
static func ring(center: Vector2i, r: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if r == 0:
		out.append(center)
		return out
	for d in range(-r, r + 1):
		out.append(center + Vector2i(d, -r))
		out.append(center + Vector2i(d, r))
		if absi(d) != r:
			out.append(center + Vector2i(-r, d))
			out.append(center + Vector2i(r, d))
	return out


## The first cell, searching rings outward from `center` up to `max_r`, where `pred(cell)`
## is true. Returns `fallback` (default: `center`) when nothing qualifies.
static func nearest(center: Vector2i, max_r: int, pred: Callable, fallback: Variant = null) -> Vector2i:
	for r in max_r + 1:
		for cell in ring(center, r):
			if pred.call(cell):
				return cell
	return center if fallback == null else fallback


## Like nearest(), for a block of `size` cells: returns the origin (top-left) of the closest
## block to `anchor` whose every cell satisfies `pred`, or `anchor` when none does.
static func nearest_block(anchor: Vector2i, size: Vector2i, max_r: int, pred: Callable) -> Vector2i:
	return nearest(anchor, max_r, func(origin: Vector2i) -> bool:
		for x in size.x:
			for y in size.y:
				if not pred.call(origin + Vector2i(x, y)):
					return false
		return true)


## Every cell reachable from `start` over 4-neighbour steps through cells where
## `passable(cell)` is true, as a Dictionary used as a set. Empty if `start` is blocked.
static func flood(start: Vector2i, passable: Callable) -> Dictionary:
	var seen: Dictionary = {}
	if not passable.call(start):
		return seen
	var open: Array[Vector2i] = [start]
	seen[start] = true
	while not open.is_empty():
		var cell: Vector2i = open.pop_back()
		for step: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var next := cell + step
			if not seen.has(next) and passable.call(next):
				seen[next] = true
				open.append(next)
	return seen


## Seeded in-place Fisher-Yates shuffle (same seed, same order on every machine).
static func shuffle(items: Array, rng: RandomNumberGenerator) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Variant = items[i]
		items[i] = items[j]
		items[j] = tmp


## Save encoding of cells: `[[x, y], ...]`.
static func cells_to_pairs(cells: Array) -> Array:
	return cells.map(func(cell: Vector2i) -> Array: return [cell.x, cell.y])


## Inverse of cells_to_pairs().
static func pairs_to_cells(pairs: Array) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for pair: Array in pairs:
		cells.append(Vector2i(int(pair[0]), int(pair[1])))
	return cells
