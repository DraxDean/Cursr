# scripts/main/main_menu.gd
extends Control

# Scene path constants
const GAME_SCENE_PATH = "res://scenes/main/game_scene.tscn" # Corrected Path
const WORLD_CREATION_SCENE_PATH = "res://scenes/main/world_creation_scene.tscn"
const LoadGameModalScript = preload("res://scripts/ui/load_game_modal.gd")
const AnnouncementsModalScript = preload("res://scripts/ui/announcements_modal.gd")
const AnnouncementsData = preload("res://data/announcements/announcements.gd")
const ANNOUNCEMENT_PREVIEW_LENGTH = 20
const RoadmapModalScript = preload("res://scripts/ui/roadmap_modal.gd")
const RoadmapData = preload("res://data/roadmap/roadmap.gd")

# Node References - Use explicit paths assuming standard setup
@onready var continue_button: Button = $CenterContainer/MainVBoxContainer/VBoxContainer/ContinueButton
@onready var new_game_button: Button = $CenterContainer/MainVBoxContainer/VBoxContainer/NewGameButton
@onready var load_game_button: Button = $CenterContainer/MainVBoxContainer/VBoxContainer/LoadGameButton
@onready var achievements_button: Button = $TopRightContainer/AchievementsButton
@onready var settings_button: Button = $TopRightContainer/SettingsButton
@onready var version_label: Label = $VersionLabel
@onready var announcements_list: VBoxContainer = $AnnouncementsPanel/MarginContainer/VBoxContainer/ScrollContainer/AnnouncementsList
@onready var roadmap_list: VBoxContainer = $RoadmapPanel/MarginContainer/VBoxContainer/ScrollContainer/RoadmapList

var _load_modal: Control = null
var _achievements_modal: Control = null
var _settings_modal: Control = null
var _announcement_modal: Control = null
var _roadmap_modal: Control = null

func _ready():
	# Ensure SaveLoadManager is ready (Autoloads initialize before scene _ready)
	# We can now directly use it
	if SaveLoadManager == null:
		push_error("SaveLoadManager Autoload not found!")
		return

	_show_version_label()

	# Connect signals
	if not is_instance_valid(continue_button): push_error("Node not found: VBoxContainer/ContinueButton"); return
	if not is_instance_valid(new_game_button): push_error("Node not found: VBoxContainer/NewGameButton"); return
	if not is_instance_valid(load_game_button): push_error("Node not found: VBoxContainer/LoadGameButton"); return
	if not is_instance_valid(achievements_button): push_error("Node not found: TopRightContainer/AchievementsButton"); return
	if not is_instance_valid(settings_button): push_error("Node not found: TopRightContainer/SettingsButton"); return

	continue_button.pressed.connect(_on_continue_pressed)
	new_game_button.pressed.connect(_on_new_game_pressed)
	load_game_button.pressed.connect(_on_load_game_pressed)
	achievements_button.pressed.connect(_on_achievements_pressed)
	settings_button.pressed.connect(_on_settings_pressed)

	_populate_announcements()
	_populate_roadmap()

	# Enable/disable buttons based on save availability
	var saves_exist = SaveLoadManager.check_saves_exist()
	continue_button.disabled = not saves_exist
	load_game_button.disabled = not saves_exist
	
	if continue_button.disabled:
		continue_button.tooltip_text = "No saved games found."
	if load_game_button.disabled:
		load_game_button.tooltip_text = "No saved games found."


func _show_version_label() -> void:
	"""Version = v0.8.<commit count>, read from git so it advances with every commit."""
	if not is_instance_valid(version_label):
		return
	var commit_count := _get_git_commit_count()
	if commit_count < 0:
		version_label.visible = false
		return
	version_label.text = "v0.8.%d" % commit_count


func _get_git_commit_count() -> int:
	"""Returns HEAD's commit count on this branch, or -1 if git isn't available (e.g. exported builds without a .git folder)."""
	var project_path := ProjectSettings.globalize_path("res://")
	var output := []
	var exit_code := OS.execute("git", ["-C", project_path, "rev-list", "--count", "HEAD"], output, true)
	if exit_code != 0 or output.is_empty():
		return -1
	var count_str: String = String(output[0]).strip_edges()
	if not count_str.is_valid_int():
		return -1
	return count_str.to_int()


func _on_continue_pressed():
	DebugConfig.dprint("ui", ["Main Menu: Continuing from last save..."])
	var most_recent_save = SaveLoadManager.get_most_recent_save()
	if most_recent_save.is_empty():
		push_warning("Continue pressed, but no save file found.")
		return
	
	GameManager.start_mode = "load"
	GameManager.load_file_path = most_recent_save
	var error = get_tree().change_scene_to_file(GAME_SCENE_PATH)
	if error != OK: push_error("Failed to change scene to %s. Error code: %d" % [GAME_SCENE_PATH, error])


func _on_new_game_pressed():
	DebugConfig.dprint("ui", ["Main Menu: Starting World Creation..."])
	GameManager.start_mode = "world_creation"
	var error = get_tree().change_scene_to_file(GAME_SCENE_PATH)
	if error != OK: push_error("Failed to change scene to %s. Error code: %d" % [GAME_SCENE_PATH, error])


func _on_load_game_pressed():
	DebugConfig.dprint("ui", ["Main Menu: Opening load game browser..."])
	# Hide main menu buttons while modal is open
	$CenterContainer.visible = false

	_load_modal = LoadGameModalScript.new()
	_load_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_load_modal.back_pressed.connect(_on_load_modal_back)
	add_child(_load_modal)


func _on_load_modal_back():
	if _load_modal and is_instance_valid(_load_modal):
		_load_modal.queue_free()
		_load_modal = null
	$CenterContainer.visible = true


func _on_achievements_pressed():
	DebugConfig.dprint("ui", ["Main Menu: Opening achievements..."])
	if not is_instance_valid(_achievements_modal):
		var EncyclopediaModalScript = preload("res://scripts/ui/encyclopedia_modal.gd")
		_achievements_modal = EncyclopediaModalScript.new()
		add_child(_achievements_modal)
	_achievements_modal.open_achievements_tab()


func _on_settings_pressed():
	DebugConfig.dprint("ui", ["Main Menu: Opening settings..."])
	if not is_instance_valid(_settings_modal):
		var SettingsModalScript = preload("res://scripts/ui/settings_modal.gd")
		_settings_modal = SettingsModalScript.new(null)
		add_child(_settings_modal)
	_settings_modal.toggle()


func _populate_announcements() -> void:
	if not is_instance_valid(announcements_list):
		return
	for child in announcements_list.get_children():
		child.queue_free()
	for entry in AnnouncementsData.ANNOUNCEMENTS:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 64)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.text = "%s\n%s\n%s" % [
			entry.get("date", ""),
			entry.get("title", ""),
			_truncate_preview(entry.get("content", "")),
		]
		btn.pressed.connect(_on_announcement_pressed.bind(entry))
		announcements_list.add_child(btn)


func _truncate_preview(text: String) -> String:
	if text.length() <= ANNOUNCEMENT_PREVIEW_LENGTH:
		return text
	return text.substr(0, ANNOUNCEMENT_PREVIEW_LENGTH) + "..."


func _on_announcement_pressed(data: Dictionary) -> void:
	DebugConfig.dprint("ui", ["Main Menu: Opening announcement '%s'..." % data.get("id", "")])
	if is_instance_valid(_announcement_modal):
		_announcement_modal.queue_free()
	_announcement_modal = AnnouncementsModalScript.new(data)
	_announcement_modal.modal_closed.connect(_on_announcement_modal_closed)
	add_child(_announcement_modal)
	_announcement_modal.toggle()


func _on_announcement_modal_closed(_type: String) -> void:
	if is_instance_valid(_announcement_modal):
		_announcement_modal.queue_free()
	_announcement_modal = null


func _populate_roadmap() -> void:
	if not is_instance_valid(roadmap_list):
		return
	for child in roadmap_list.get_children():
		child.queue_free()
	for entry in RoadmapData.MILESTONES:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 48)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var status_label: String = "✅ Completed" if entry.get("status", "") == "completed" else "🔭 Planned"
		btn.text = "%s — %s\n%s" % [entry.get("version", ""), entry.get("title", ""), status_label]
		btn.pressed.connect(_on_roadmap_pressed.bind(entry))
		roadmap_list.add_child(btn)


func _on_roadmap_pressed(data: Dictionary) -> void:
	DebugConfig.dprint("ui", ["Main Menu: Opening roadmap milestone '%s'..." % data.get("version", "")])
	if is_instance_valid(_roadmap_modal):
		_roadmap_modal.queue_free()
	_roadmap_modal = RoadmapModalScript.new(data)
	_roadmap_modal.modal_closed.connect(_on_roadmap_modal_closed)
	add_child(_roadmap_modal)
	_roadmap_modal.toggle()


func _on_roadmap_modal_closed(_type: String) -> void:
	if is_instance_valid(_roadmap_modal):
		_roadmap_modal.queue_free()
	_roadmap_modal = null

