extends Node
## Global para (Zurna) sistemi.
## KURULUM: Project Settings > Autoload'a bu scripti "GlobalEconomy" adıyla eklemen gerekiyor.

signal money_changed(new_amount: int)

var money: int = 0


func add_money(amount: int) -> void:
	if amount <= 0:
		return
	money += amount
	emit_signal("money_changed", money)


func spend_money(amount: int) -> bool:
	if amount <= 0:
		return true
	if money < amount:
		return false

	money -= amount
	emit_signal("money_changed", money)
	return true


func has_enough(amount: int) -> bool:
	return money >= amount
