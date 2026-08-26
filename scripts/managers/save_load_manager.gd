# scripts/managers/save_load_manager.gd
extends Node

const SAVE_DIR = "user://CursrSaves/"

func _ready():
	# Ensure save directory exists when the game starts
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	DebugConfig.dprint("save_load", ["SaveLoadManager ready. Save directory ensured: %s" % SAVE_DIR])

# Saves the provided game state dictionary to a file.
# If file_path is empty, uses current_save_path or finds the next available name.
# Returns the path used for saving on success, or an empty string on failure.
func save_game(game_state: Dictionary, file_path: String = "") -> String:
	var path_to_save = file_path
	if path_to_save.is_empty():
		if game_state.has("current_save_path") and not game_state["current_save_path"].is_empty():
			path_to_save = game_state["current_save_path"]
		else:
			path_to_save = _find_next_save_name()
			if path_to_save.is_empty(): return "" # Failed to find a name

	DebugConfig.dprint("save_load", ["SaveLoadManager: Attempting to save game state to: %s" % path_to_save])

	if not game_state.has("map_data") or not game_state.has("current_day"):
		push_error("SaveLoadManager: Invalid game_state dictionary provided for saving.")
		return ""

	if game_state["map_data"].is_empty():
		push_warning("SaveLoadManager: Attempted to save empty world data.")
		# Allow saving empty data if intended

	var file = FileAccess.open(path_to_save, FileAccess.WRITE)
	if FileAccess.get_open_error() == OK and is_instance_valid(file):
		# Store the entire game_state dictionary
		file.store_var(game_state)
		DebugConfig.dprint("save_load", ["SaveLoadManager: Game state saved successfully to %s" % path_to_save])
		return path_to_save # Return the path used
	else:
		push_error("SaveLoadManager: Failed to open file for writing '%s'. Error: %s" % [path_to_save, error_string(FileAccess.get_open_error())])
		return ""

# Loads game state from a specific file path.
# Returns the loaded game state dictionary on success, or an empty dictionary on failure.
func load_game(file_path: String) -> Dictionary:
	DebugConfig.dprint("save_load", ["SaveLoadManager: Loading game state from: %s" % file_path])
	if file_path.is_empty() or not FileAccess.file_exists(file_path):
		push_error("SaveLoadManager: Save file does not exist or path is empty: %s" % file_path); return {}

	var file = FileAccess.open(file_path, FileAccess.READ)
	if FileAccess.get_open_error() != OK or not is_instance_valid(file):
		push_error("SaveLoadManager: Failed to open file for reading '%s'. Error: %s" % [file_path, error_string(FileAccess.get_open_error())]); return {}

	if file.get_length() == 0: push_error("SaveLoadManager: Save file is empty: %s" % file_path); return {}

	var loaded_save_data = file.get_var()
	if FileAccess.get_open_error() != OK: push_error("SaveLoadManager: Error reading data from file '%s'. Error: %s" % [file_path, error_string(FileAccess.get_open_error())]); return {}

	if typeof(loaded_save_data) == TYPE_DICTIONARY:
		# Basic validation (could add more checks)
		if loaded_save_data.has("map_data") and loaded_save_data.has("current_day"):
			DebugConfig.dprint("save_load", ["SaveLoadManager: Game state loaded successfully."])
			loaded_save_data["current_save_path"] = file_path # Add the loaded path to the state dict
			return loaded_save_data
		else:
			push_error("SaveLoadManager: Loaded dictionary is missing required keys ('map_data', 'current_day').")
			return {}
	else:
		push_error("SaveLoadManager: Loaded data not Dictionary format. Found type: %s" % typeof(loaded_save_data))
		return {}

# Finds the next available save file name (e.g., world3.save)
func _find_next_save_name() -> String:
	var highest_num = 0
	var dir = DirAccess.open(SAVE_DIR)
	if not dir: push_error("SaveLoadManager: Cannot open save directory: %s" % SAVE_DIR); return ""

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.begins_with("world") and file_name.ends_with(".save"):
			var num_str = file_name.trim_prefix("world").trim_suffix(".save")
			if num_str.is_valid_int(): highest_num = max(highest_num, num_str.to_int())
		file_name = dir.get_next()
	dir.list_dir_end()

	var next_num = highest_num + 1
	var next_filename = "world%d.save" % next_num
	return SAVE_DIR.path_join(next_filename)

# Checks if any save files exist in the directory
func check_saves_exist() -> bool:
	var dir = DirAccess.open(SAVE_DIR)
	var save_exists = false
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".save"):
				save_exists = true; break
			file_name = dir.get_next()
		dir.list_dir_end()
	return save_exists

# Gets the most recent save file path based on modification time
func get_most_recent_save() -> String:
	var dir = DirAccess.open(SAVE_DIR)
	if not dir:
		return ""
	
	var most_recent_file = ""
	var most_recent_time = 0
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".save"):
			var full_path = SAVE_DIR.path_join(file_name)
			var file_time = FileAccess.get_modified_time(full_path)
			if file_time > most_recent_time:
				most_recent_time = file_time
				most_recent_file = full_path
		file_name = dir.get_next()
	dir.list_dir_end()
	
	return most_recent_file

# Returns metadata for all save files without loading full game state.
# Each entry: { path, filename, modified_time, current_day, population, save_name }
func get_all_saves_info() -> Array:
	var result: Array = []
	var dir = DirAccess.open(SAVE_DIR)
	if not dir:
		return result
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".save"):
			var full_path = SAVE_DIR.path_join(file_name)
			var info = {
				"path": full_path,
				"filename": file_name,
				"modified_time": FileAccess.get_modified_time(full_path),
				"current_day": 0,
				"population": 0,
				"difficulty": "captain",
				"save_name": file_name.trim_suffix(".save")
			}
			# Peek into the save for lightweight data
			var file = FileAccess.open(full_path, FileAccess.READ)
			if file and FileAccess.get_open_error() == OK:
				var data = file.get_var()
				if typeof(data) == TYPE_DICTIONARY:
					info["current_day"] = data.get("current_day", 0)
					info["difficulty"] = data.get("difficulty", "captain")
					var pd = data.get("players_data", {})
					for pid in pd:
						if str(pid) != "environment":
							info["population"] = pd[pid].get("population", {}).get("total", 0)
							break
			result.append(info)
		file_name = dir.get_next()
	dir.list_dir_end()
	# Sort newest first
	result.sort_custom(func(a, b): return a["modified_time"] > b["modified_time"])
	return result

func delete_save(file_path: String) -> bool:
	if not FileAccess.file_exists(file_path):
		return false
	var err = DirAccess.remove_absolute(file_path)
	return err == OK
