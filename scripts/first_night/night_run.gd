class_name NightRun
extends RefCounted

enum Phase { SHOP, NIGHT, REPORT }
const BUDGET := 10
const PRICES := {&"blanket": 6, &"bar": 7, &"drink": 3}
const LIMITS := {&"blanket": 1, &"bar": 1, &"drink": 2}
const NAMES := {&"blanket": "防雨毯", &"bar": "小撬棍", &"drink": "罐装粥"}
const ROUTES := {&"booth": "街口值班亭", &"pump": "旧泵房", &"stay": "留守据点"}

var phase := Phase.SHOP
var money := BUDGET
var purchases := {&"blanket": 0, &"bar": 0, &"drink": 0}
# Hunger and wetness increase toward danger. Health and sanity increase toward safety.
var health := 60
var hunger := 50
var wetness := 35
var sanity := 60
var drinks_left := 0
var used_sense := false
var route: StringName = &""
var fuel := 0
var ledger: PackedStringArray = []


func buy(item: StringName) -> String:
	if phase != Phase.SHOP or not PRICES.has(item):
		return "采购已结束。"
	if money < PRICES[item]:
		return "余额不足。剩余 %d 券，每份%s需 %d 券。" % [money, NAMES[item], PRICES[item]]
	if purchases[item] >= LIMITS[item]:
		return "%s已达到本次携带上限。" % NAMES[item]
	money -= int(PRICES[item])
	purchases[item] += 1
	return "已装入%s。" % NAMES[item]


func refund(item: StringName) -> void:
	if phase == Phase.SHOP and purchases.get(item, 0) > 0:
		purchases[item] -= 1
		money += int(PRICES[item])


func begin_night() -> void:
	if phase != Phase.SHOP:
		return
	phase = Phase.NIGHT
	drinks_left = purchases[&"drink"]


func sense() -> bool:
	if phase != Phase.NIGHT or used_sense or not route.is_empty():
		return false
	used_sense = true
	sanity = maxi(0, sanity - 20)
	ledger.append("循着回声辨认锁柜，SAN −20。")
	return true


func drink() -> bool:
	if phase != Phase.NIGHT or drinks_left <= 0:
		return false
	drinks_left -= 1
	var before := hunger
	hunger = maxi(0, hunger - 30)
	ledger.append("吃下一罐粥，饥饿 −%d。" % (before - hunger))
	return true


func search(place: StringName) -> bool:
	if phase != Phase.NIGHT or not route.is_empty() or place not in [&"booth", &"pump"]:
		return false
	route = place
	var far := place == &"pump"
	var hunger_gain := 20 if far else 10
	var rain := 40 if far else 20
	if purchases[&"blanket"] > 0:
		rain -= 15
	hunger = mini(100, hunger + hunger_gain)
	wetness = mini(100, wetness + rain)
	fuel = 3 if far and purchases[&"bar"] > 0 else 1
	ledger.append("%s往返：饥饿 +%d，潮湿 +%d，燃料 ×%d。" % [ROUTES[route], hunger_gain, rain, fuel])
	return true


func settle() -> bool:
	if phase != Phase.NIGHT:
		return false
	if route.is_empty():
		route = &"stay"
	var before_wet := wetness
	var drying := fuel * 20
	if purchases[&"blanket"] > 0:
		drying += 25
	hunger = mini(100, hunger + 20)
	wetness = clampi(wetness + 35 - drying, 0, 100)
	var hungry := hunger >= 80
	var soaked := wetness >= 65
	var sanity_loss := 10 + 10 * int(hungry) + 10 * int(soaked)
	sanity = maxi(0, sanity - sanity_loss)
	var causes := PackedStringArray()
	if hungry:
		causes.append("饥饿")
	if soaked:
		causes.append("潮湿")
	if sanity <= 25:
		causes.append("SAN 过低")
	var before_hp := health
	health = maxi(0, health - 20 * causes.size())
	ledger.append("守夜：饥饿 +20，潮湿 %d → %d，SAN −%d。" % [before_wet, wetness, sanity_loss])
	if causes.is_empty():
		ledger.append("衣食尚可，天亮时没有新增伤势。")
	else:
		ledger.append("%s：生命 −%d。" % ["、".join(causes), before_hp - health])
	phase = Phase.REPORT
	return true


func manifest() -> String:
	var parts := PackedStringArray()
	for item in PRICES:
		if purchases[item] > 0:
			parts.append("%s ×%d" % [NAMES[item], purchases[item]])
	return "空背包" if parts.is_empty() else "、".join(parts)
