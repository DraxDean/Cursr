extends Node
## Central switchboard for all debug print() output in the game.
## Flip a category below to silence/enable that system's debug logs
## without touching any call sites. Call sites use:
##   DebugConfig.dprint("movement", ["some ", value, " text"])

# Master switch - turns all debug output on/off regardless of category
@export var debug_enabled: bool = false

# Per-system toggles. Set to false to silence that category's debug prints.
var categories: Dictionary = {
	"movement": false,      # Unit movement/pathfinding cycle logs - very noisy, silenced by default
	"jobs": true,           # Job creation / assignment
	"population": true,     # Housing / employment / population growth
	"buildings": true,      # Building placement / demolition / connections
	"naming": true,         # Unit & workplace name generation/assignment
	"save_load": true,      # Save/load and data migration
	"world_gen": true,      # World generation & world creation flow
	"ui": true,             # UI modal debug logs
	"achievements": true,
	"camera": true,
	"map_objects": true,    # Environment objects (trees/mountains/fish/farms)
	"turn_events": true,
	"wave": true,           # Enemy waves / combat / unit training
	"general": true,        # Catch-all / misc
}

func is_enabled(category: String) -> bool:
	return debug_enabled and categories.get(category, true)

## Prints args (concatenated like print()) only if the category is enabled.
func dprint(category: String, args: Array) -> void:
	if not is_enabled(category):
		return
	var msg := ""
	for a in args:
		msg += str(a)
	print(msg)
