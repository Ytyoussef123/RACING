class_name HeldKick
extends RefCounted
## PASS, THROUGH or CLEAR held by the human (the kick goes on release). Released after a tap
## (kick_tap_seconds) a ground kick gets the automatic power; held longer, the power bar fills over
## kick_charge_time and sets the power. A lofted pass or through ball (the finger slid up on the
## button) always takes the bar's power, filled from the press: its length is the bar's.
## Numbers: data/config/player.json (kick_*).

## "pass", "through" or "clear" while held, else "".
var kind: String = ""
## Seconds held.
var time: float = 0.0
## The finger is slid up (a ball in the air), on the last held frame.
var lofted: bool = false
## 0..1: the bar of a ground kick (it starts after the tap time).
var charge: float = 0.0


func reset() -> void:
	kind = ""
	time = 0.0
	lofted = false
	charge = 0.0


## Every frame. When a held button was let go, returns the kick to queue now:
## {"kind", "power", "lofted"}; otherwise an empty Dictionary.
func update(intent: PlayerIntent, delta: float) -> Dictionary:
	var held := ""
	if intent.pass_held:
		held = "pass"
	elif intent.through_held:
		held = "through"
	elif intent.clear_held:
		held = "clear"
	if intent.kick_cancel:
		reset()
		return {}
	var released := {}
	if not held.is_empty() and held == kind:
		time += delta
		lofted = _lofted(intent, held)
	else:
		if not kind.is_empty():
			var up := lofted or _lofted(intent, kind)
			var power := loft_power() if up else (Kicks.AUTO if time <= _tap() else charge)
			released = {"kind": kind, "power": power, "lofted": up}
		kind = held
		time = 0.0
		lofted = _lofted(intent, held)
	charge = 0.0
	if not kind.is_empty():
		charge = clampf((time - _tap()) / _charge_time(), 0.0, 1.0)
	return released


## Power of a lofted kick: the bar fills from the press.
func loft_power() -> float:
	return clampf(time / _charge_time(), 0.0, 1.0)


func bar_value() -> float:
	return loft_power() if lofted else charge


## The bar shows on a lofted kick at once, on a ground kick after the tap time.
func shown() -> bool:
	return not kind.is_empty() and (lofted or time > _tap())


static func _lofted(intent: PlayerIntent, which: String) -> bool:
	return (which == "pass" and intent.pass_lofted) or (which == "through" and intent.through_lofted)


static func _tap() -> float:
	return float(Config.get_value("player", "kick_tap_seconds", 0.18))


static func _charge_time() -> float:
	return maxf(0.01, float(Config.get_value("player", "kick_charge_time", 0.6)))
