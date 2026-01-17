# scripts/main/game_manager.gd - Autoload
extends Node

# start_mode: "new", "load", "new_with_data", "world_creation"
var start_mode: String = "new"

# Path of the specific save file to load when start_mode is "load"
var load_file_path: String = ""

# Generated world data for interactive world creation
var generated_world_data: Dictionary = {}

# No longer need return_scene_path if using in-game load modal
