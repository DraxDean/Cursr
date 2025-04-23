# scripts/main/game_manager.gd - Autoload
extends Node

# start_mode: "new", "load"
var start_mode: String = "new"

# Path of the specific save file to load when start_mode is "load"
var load_file_path: String = ""

# No longer need return_scene_path if using in-game load modal
