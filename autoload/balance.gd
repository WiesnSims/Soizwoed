extends Node
## Gives the whole game access to res://balance.tres as `Balance.config`.

const CONFIG_PATH: String = "res://balance.tres"

var config: BalanceConfig = load(CONFIG_PATH) as BalanceConfig
