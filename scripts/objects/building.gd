class_name Building
extends Node  

#visual
var building_data;
var path;
var size;
var coords;

#game
var allegiance;

var upkeep;
var production;

#construction
var finished;
var cost;
var progress;

func setup(new_building_data):
	building_data = new_building_data
	path = building_data.path
	name = building_data.name
	
	var texture = load(building_data.path)
	if texture is Texture2D or texture is CompressedTexture2D: 
		$Sprite2D.texture = texture
		$Sprite2D.set_meta("building_data", building_data)
		
		# Optional: Scale the sprite to fit your desired size
		# var desired_size = Vector2(64, 64)
		# var texture_size = texture.get_size()
		# $Sprite2D.scale = desired_size / texture_size
		
	else:
		printerr("Building: Error loading texture:", building_data.path)
		# Create a placeholder or error sprite
		$Sprite2D.texture = null
