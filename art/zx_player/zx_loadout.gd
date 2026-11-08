class_name ZXLoadout
extends RefCounted
## Saves / loads the menu choice (skin + weapon) to user://zx_loadout.cfg and applies it to a ZXPlayer.

const PATH := "user://zx_loadout.cfg"


static func save(skin: int, weapon: String) -> void:
	var c := ConfigFile.new()
	c.set_value("player", "skin", skin)
	c.set_value("player", "weapon", weapon)
	c.save(PATH)


static func load_choice() -> Dictionary:
	var c := ConfigFile.new()
	if c.load(PATH) != OK:
		return {"skin": 0, "weapon": "assault_rifle"}
	return {"skin": c.get_value("player", "skin", 0), "weapon": c.get_value("player", "weapon", "assault_rifle")}


static func apply(player: ZXPlayer) -> void:
	var d := load_choice()
	player.set_skin(d.skin)
	player.equip(d.weapon)
