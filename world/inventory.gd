class_name Inventory
extends RefCounted
## A pack of so many slots. Each slot holds one kind of thing, up to its stack.

signal changed

var slots: Array = []


func _init(n := 24) -> void:
	slots.resize(n)
	slots.fill(null)


func count(id: String) -> int:
	var n := 0
	for s in slots:
		if s != null and s.id == id:
			n += int(s.n)
	return n


func has_all(cost: Dictionary) -> bool:
	for k in cost:
		if count(k) < int(cost[k]):
			return false
	return true


## Adds what fits; returns what did not.
func add(id: String, n: int) -> int:
	var cap := Items.stack_of(id)
	for s in slots:
		if n <= 0:
			break
		if s != null and s.id == id and s.n < cap:
			var put := mini(cap - int(s.n), n)
			s.n += put
			n -= put
	for i in slots.size():
		if n <= 0:
			break
		if slots[i] == null:
			var put := mini(cap, n)
			slots[i] = {"id": id, "n": put}
			n -= put
	changed.emit()
	return n


func room_for(id: String, n: int) -> bool:
	var cap := Items.stack_of(id)
	for s in slots:
		if s == null:
			n -= cap
		elif s.id == id:
			n -= cap - int(s.n)
		if n <= 0:
			return true
	return n <= 0


## Takes up to n; returns how many were taken.
func take(id: String, n: int) -> int:
	var got := 0
	for i in range(slots.size() - 1, -1, -1):
		var s = slots[i]
		if got >= n:
			break
		if s != null and s.id == id:
			var t := mini(int(s.n), n - got)
			s.n -= t
			got += t
			if s.n <= 0:
				slots[i] = null
	changed.emit()
	return got


func pay(cost: Dictionary) -> bool:
	if not has_all(cost):
		return false
	for k in cost:
		take(k, int(cost[k]))
	return true


func take_slot(i: int) -> Variant:
	var s = slots[i]
	slots[i] = null
	changed.emit()
	return s


func is_empty() -> bool:
	for s in slots:
		if s != null:
			return false
	return true


## Makes room for more (never less): a deeper pack.
func grow(n: int) -> void:
	if n > slots.size():
		slots.resize(n)
		changed.emit()


func to_data() -> Array:
	var out: Array = []
	for s in slots:
		out.append(null if s == null else [s.id, int(s.n)])
	return out


func from_data(d: Array) -> void:
	slots.fill(null)
	for i in mini(d.size(), slots.size()):
		if d[i] != null and d[i] is Array and d[i].size() == 2:
			slots[i] = {"id": str(d[i][0]), "n": int(d[i][1])}
	changed.emit()
