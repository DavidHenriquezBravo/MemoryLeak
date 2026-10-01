class_name RewardData
extends Resource

enum Stat { DAMAGE, ARMOR, LUCK, MAX_HP }

@export var stat: Stat = Stat.DAMAGE
# DAÑO y VIDA: número entero (2, 5...). ARMADURA y SUERTE: fracción (0.05 = 5%)
@export var amount: float = 0.0


func label() -> String:
	match stat:
		Stat.DAMAGE:
			return "+%d DAÑO" % int(amount)
		Stat.ARMOR:
			return "+%d%% ARMADURA" % roundi(amount * 100.0)
		Stat.LUCK:
			return "+%d%% SUERTE" % roundi(amount * 100.0)
		Stat.MAX_HP:
			return "+%d VIDA" % int(amount)
	return ""
