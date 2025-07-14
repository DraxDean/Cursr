extends Node

var map_manager;
@onready var build_button = $build_button;

func setup(new_map_manager):
	print("UI Setup")
	map_manager = new_map_manager;
	
#	link signal 
	build_button.pressed.connect(_on_pressed_build_button)

func _on_pressed_build_button(event):
	#if event is InputEventMouseButton and event.pressed:
		#print("Button clicked!")
	print("build!");
