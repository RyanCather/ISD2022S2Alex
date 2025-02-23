extends Control

func _ready():
	Globals.connect("toggle_network_setup", self, "_toggle_network_setup")

func _on_IpAddress_text_changed(new_text):
	Network.ip_address = new_text

func _on_Host_pressed():
	Network.create_server()
	hide()

func _on_Join_pressed():
	Network.join_server()
	hide()

func _toggle_network_setup(visible_toggle):
	visible = visible_toggle
