extends AcceptDialog

func _ready():
	popup_centered()
	$Button.text = "Test Button"
	$Button.pressed.connect(_on_test_pressed)
	print("Modal ready, button created")

func _on_test_pressed():
	print("TEST BUTTON PRESSED!")

func _input(event):
	print("Modal received input: ", event)
