extends KinematicBody

const GRAVITY = -100 # Player gravity
var vel = Vector3()
const MAX_SPEED = 22.5 # Player move speed
const JUMP_SPEED = 40 # Jump height/power
const ACCEL = 10 # Time taken to reach max speed

var dir = Vector3()

var player_node = null

const DEACCEL= 10 #Time taken to slow down
const MAX_SLOPE_ANGLE = 40

var camera
var rotation_helper

var MOUSE_SENSITIVITY = 0.15 # Sensitivity

const MAX_SPRINT_SPEED = 35
const SPRINT_ACCEL = 10
var is_sprinting = false

var flashlight

var JOYPAD_SENSITIVITY = 2
const JOYPAD_DEADZONE = 0.15

var mouse_scroll_value = 0
const MOUSE_SENSITIVITY_SCROLL_WHEEL = 0.08

const MAX_HEALTH = 150 # This number is the maximum health the player can have.

var grabbed_object = null
const OBJECT_THROW_FORCE = 150 # The force with which objects are thrpwn by the player.
const OBJECT_GRAB_DISTANCE = 10 # The distance at which an object is held.
const OBJECT_GRAB_RAY_DISTANCE = 15 # The distance from which the player can grab objects.

const RESPAWN_TIME = 4 # Amount of time (in seconds) it takes to respawn.
var dead_time = 0 # Variable that tracks how long the player has been dead for.
var is_dead = false # Variable that tracks whether or not the player is dead.

var globals
##############################################
########################const POPUP_SCENE2 = preload("res://ShopUI.tscn")
var POPUP_SCENE
var popup = null # Variable to hold popup scene.
var shop_open = false
##############################################
# ----------------------------------
# Weapons
var animation_manager

var current_weapon_name = "CLICK" #Not the state the player begins in
var weapons = {"UNARMED":null, "KNIFE":null, "PISTOL":null, "RIFLE":null, "CLICK":null}
const WEAPON_NUMBER_TO_NAME = {4:"UNARMED", 1:"KNIFE", 2:"PISTOL", 3:"RIFLE", 0:"CLICK"}
const WEAPON_NAME_TO_NUMBER = {"UNARMED":4, "KNIFE":1, "PISTOL":2, "RIFLE":3, "CLICK":0}
var changing_weapon = false
var changing_weapon_name = "CLICK"

var health = 100

var UI_status_label
var UI_status_label2

var reloading_weapon = false # Checks to see if the player is currently trying to reload.

var grenade_amounts = {"Grenade":2, "Sticky Grenade":2} # amount of grenades the player is holding (for each type).
var current_grenade = "Grenade"
var grenade_scene = preload("res://Grenade.tscn")
var sticky_grenade_scene = preload("res://Sticky_Grenade.tscn") # The force with which grenades are thrown.
const GRENADE_THROW_FORCE = 75

################################################################################const POPUP_SCENE2 = preload("res://Tutorial.tscn")
################################################################################var popup2 = null

# ----------------------------------

func _ready():

	POPUP_SCENE = $HUD/ShopUI
	##########################
	camera = $Rotation_Helper/Camera
	rotation_helper = $Rotation_Helper

	animation_manager = $Rotation_Helper/Model/Animation_Player
	animation_manager.callback_function = funcref(self, "fire_bullet")

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	#weapons["UNARMED"] = $Rotation_Helper/Gun_Fire_Points/Click_Point
	weapons["KNIFE"] = $Rotation_Helper/Gun_Fire_Points/Knife_Point
	weapons["PISTOL"] = $Rotation_Helper/Gun_Fire_Points/Pistol_Point
	weapons["RIFLE"] = $Rotation_Helper/Gun_Fire_Points/Rifle_Point
	weapons["CLICK"] = $Rotation_Helper/Gun_Fire_Points/Click_Point

	var gun_aim_point_pos = $Rotation_Helper/Gun_Aim_Point.global_transform.origin

	for weapon in weapons:
		var weapon_node = weapons[weapon]
		if weapon_node != null:
			weapon_node.player_node = self
			weapon_node.look_at(gun_aim_point_pos, Vector3(0, 1, 0))
			weapon_node.rotate_object_local(Vector3(0, 1, 0), deg2rad(180))

	current_weapon_name = "CLICK"
	changing_weapon_name = "UNARMED"

	UI_status_label = $HUD/UI/Panel/Gun_label
	UI_status_label2 = $HUD/UI/Panel2/Gun_label2
	flashlight = $Rotation_Helper/Flashlight

	globals = get_node("/root/Globals")
	global_transform.origin = globals.get_respawn_position()

func _physics_process(delta):

	if !is_dead:
		process_input(delta)
		process_view_input(delta)
		process_movement(delta)

	if (grabbed_object == null):
		process_changing_weapons(delta)
		process_reloading(delta)

	process_UI(delta)
	process_respawn(delta)

func process_input(delta):
	# ----------------------------------
	# Walking
	dir = Vector3()
	var cam_xform = camera.get_global_transform()

	var input_movement_vector = Vector2()

	if Input.is_action_pressed("movement_forward"):
		input_movement_vector.y += 1
	if Input.is_action_pressed("movement_backward"):
		input_movement_vector.y -= 1
	if Input.is_action_pressed("movement_left"):
		input_movement_vector.x -= 1
	if Input.is_action_pressed("movement_right"):
		input_movement_vector.x += 1

	# PlayStation Controller Controls
	if Input.get_connected_joypads().size() > 0:

		var joypad_vec = Vector2(0, 0)

		if OS.get_name() == "Windows" or OS.get_name() == "X11":
			joypad_vec = Vector2(Input.get_joy_axis(0, 0), -Input.get_joy_axis(0, 1))
		elif OS.get_name() == "OSX":
			joypad_vec = Vector2(Input.get_joy_axis(0, 1), Input.get_joy_axis(0, 2))

		if joypad_vec.length() < JOYPAD_DEADZONE:
			joypad_vec = Vector2(0, 0)
		else:
			joypad_vec = joypad_vec.normalized() * ((joypad_vec.length() - JOYPAD_DEADZONE) / (1 - JOYPAD_DEADZONE))

		input_movement_vector += joypad_vec

	input_movement_vector = input_movement_vector.normalized()

	# Basis vectors are already normalized.
	dir += -cam_xform.basis.z * input_movement_vector.y
	dir += cam_xform.basis.x * input_movement_vector.x
	# ----------------------------------
	
	# ----------------------------------
	# Changing and throwing grenades

	if Input.is_action_just_pressed("change_grenade"):
		if current_grenade == "Grenade":
			current_grenade = "Sticky Grenade"
		elif current_grenade == "Sticky Grenade":
			current_grenade = "Grenade"

	if Input.is_action_just_pressed("fire_grenade"): # Checks to see if the player is pressing the grenade button.
		if grenade_amounts[current_grenade] > 0:     # Checks to see if the player has more than 0 grenades.
			grenade_amounts[current_grenade] -= 1    # Subtracts 1 from grenade_amount because the player just threw one.

			var grenade_clone
			if current_grenade == "Grenade": # Checks to see what grenade the player is trying to throw.
				grenade_clone = grenade_scene.instance() # Throws regular grenade.
			elif current_grenade == "Sticky Grenade": # Checks to see what grenade the player is trying to throw.
				grenade_clone = sticky_grenade_scene.instance() # Throws sticky grenade.
				# Sticky grenades will stick to the player if we do not pass ourselves
				grenade_clone.player_body = self

			get_tree().root.add_child(grenade_clone)
			grenade_clone.global_transform = $Rotation_Helper/Grenade_Toss_Pos.global_transform
			grenade_clone.apply_impulse(Vector3(0, 0, 0), grenade_clone.global_transform.basis.z * GRENADE_THROW_FORCE)
# ----------------------------------

# ----------------------------------
# Grabbing and throwing objects

	if Input.is_action_just_pressed("grab_object") and current_weapon_name == "UNARMED":
		if grabbed_object == null:
			var state = get_world().direct_space_state

			var center_position = get_viewport().size / 2
			var ray_from = camera.project_ray_origin(center_position)
			var ray_to = ray_from + camera.project_ray_normal(center_position) * OBJECT_GRAB_RAY_DISTANCE

			var ray_result = state.intersect_ray(ray_from, ray_to, [self, $Rotation_Helper/Gun_Fire_Points/Knife_Point/Area])
			if !ray_result.empty():
				if ray_result["collider"] is RigidBody:
					grabbed_object = ray_result["collider"]
					grabbed_object.mode = RigidBody.MODE_STATIC

					grabbed_object.collision_layer = 0
					grabbed_object.collision_mask = 0

		else:
			grabbed_object.mode = RigidBody.MODE_RIGID

			grabbed_object.apply_impulse(Vector3(0, 0, 0), -camera.global_transform.basis.z.normalized() * OBJECT_THROW_FORCE)

			grabbed_object.collision_layer = 1
			grabbed_object.collision_mask = 1

			grabbed_object = null

	if grabbed_object != null:
		grabbed_object.global_transform.origin = camera.global_transform.origin + (-camera.global_transform.basis.z.normalized() * OBJECT_GRAB_DISTANCE)


# ----------------------------------

func process_view_input(delta):

	if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		return

	# NOTE: Until some bugs relating to captured mice are fixed, we cannot put the mouse view
	# rotation code here. Once the bug(s) are fixed, code for mouse view rotation code will go here!

	# ----------------------------------
	# Joypad rotation

	var joypad_vec = Vector2()
	if Input.get_connected_joypads().size() > 0:

		if OS.get_name() == "Windows" or OS.get_name() == "X11":
			joypad_vec = Vector2(Input.get_joy_axis(0, 2), Input.get_joy_axis(0, 3))
		elif OS.get_name() == "OSX":
			joypad_vec = Vector2(Input.get_joy_axis(0, 3), Input.get_joy_axis(0, 4))

		if joypad_vec.length() < JOYPAD_DEADZONE:
			joypad_vec = Vector2(0, 0)
		else:
			joypad_vec = joypad_vec.normalized() * ((joypad_vec.length() - JOYPAD_DEADZONE) / (1 - JOYPAD_DEADZONE))

		rotation_helper.rotate_x(deg2rad(joypad_vec.y * JOYPAD_SENSITIVITY))

		rotate_y(deg2rad(joypad_vec.x * JOYPAD_SENSITIVITY * -1))

		var camera_rot = rotation_helper.rotation_degrees
		camera_rot.x = clamp(camera_rot.x, -70, 70)
		rotation_helper.rotation_degrees = camera_rot
	# ----------------------------------

	# ----------------------------------
	# Sprinting
	if Input.is_action_pressed("movement_sprint"):
		is_sprinting = true
	else:
		is_sprinting = false
	# ----------------------------------
	
	# ----------------------------------
	# Turning the flashlight on/off
	if Input.is_action_just_pressed("flashlight"):
		if flashlight.is_visible_in_tree():
			flashlight.hide()
		else:
			flashlight.show()

	# ----------------------------------
	# Jumping
	if is_on_floor():
		if Input.is_action_just_pressed("movement_jump"):
			vel.y = JUMP_SPEED
	# ----------------------------------

	# ----------------------------------
	# Capturing/Freeing the cursor
	if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	# ----------------------------------

	# ----------------------------------
	# Changing weapons
	var weapon_change_number = WEAPON_NAME_TO_NUMBER[current_weapon_name]
	if Input.is_key_pressed(KEY_1):
		weapon_change_number = 0
	if Input.is_key_pressed(KEY_2):
		weapon_change_number = 1
	if Input.is_key_pressed(KEY_3):
		weapon_change_number = 2
	if Input.is_key_pressed(KEY_4):
		weapon_change_number = 3
	if Input.is_key_pressed(KEY_5):
		weapon_change_number = 4

	if Input.is_action_just_pressed("shift_weapon_positive"):
		weapon_change_number += 1
	if Input.is_action_just_pressed("shift_weapon_negative"):
		weapon_change_number -= 1

	weapon_change_number = clamp(weapon_change_number, 0, WEAPON_NUMBER_TO_NAME.size() - 1)

	if changing_weapon == false:
		if reloading_weapon == false:
			if WEAPON_NUMBER_TO_NAME[weapon_change_number] != current_weapon_name:
				changing_weapon_name = WEAPON_NUMBER_TO_NAME[weapon_change_number]
				changing_weapon = true
				mouse_scroll_value = weapon_change_number
# ----------------------------------

# ----------------------------------
# Firing the weapons
# ----------------------------------
	if current_weapon_name == "CLICK":
		if Input.is_action_just_released("fire"):
			if reloading_weapon == false:
				if changing_weapon == false:
					var current_weapon = weapons[current_weapon_name]
					if current_weapon != null:
						if current_weapon.ammo_in_weapon > 0:
								fire_bullet()
						else:
							reloading_weapon = true
	else:
		if Input.is_action_pressed("fire"):
			if reloading_weapon == false:
				if changing_weapon == false:
					var current_weapon = weapons[current_weapon_name]
					if current_weapon != null:
						if current_weapon.ammo_in_weapon > 0:
							if animation_manager.current_state == current_weapon.IDLE_ANIM_NAME:
								animation_manager.set_animation(current_weapon.FIRE_ANIM_NAME)
					else:
						reloading_weapon = true
# ----------------------------------
# Reloading
	if reloading_weapon == false:
		if changing_weapon == false:
			if Input.is_action_just_pressed("reload"):
				var current_weapon = weapons[current_weapon_name]
				if current_weapon != null:
					if current_weapon.CAN_RELOAD == true:
						var current_anim_state = animation_manager.current_state
						var is_reloading = false
						for weapon in weapons:
							var weapon_node = weapons[weapon]
							if weapon_node != null:
								print (weapon)
								if str(weapon) != "CLICK":
									if current_anim_state == weapon_node.RELOADING_ANIM_NAME:
										is_reloading = true
						if is_reloading == false:
							reloading_weapon = true
# ----------------------------------

func process_changing_weapons(delta):
	if changing_weapon == true:

		var weapon_unequipped = false
		var current_weapon = weapons[current_weapon_name]

		if current_weapon == null:
			weapon_unequipped = true
		else:
			if current_weapon.is_weapon_enabled == true:
				weapon_unequipped = current_weapon.unequip_weapon()
			else:
				weapon_unequipped = true

		if weapon_unequipped == true:

			var weapon_equipped = false
			var weapon_to_equip = weapons[changing_weapon_name]

			if weapon_to_equip == null:
				weapon_equipped = true
			else:
				if weapon_to_equip.is_weapon_enabled == false:
					 weapon_equipped = weapon_to_equip.equip_weapon()
				else:
					weapon_equipped = true

			if weapon_equipped == true:
				changing_weapon = false
				current_weapon_name = changing_weapon_name
				changing_weapon_name = ""

func fire_bullet():
	if changing_weapon == true:
		return

	weapons[current_weapon_name].fire_weapon()

func process_movement(delta):
	dir.y = 0
	dir = dir.normalized()

	vel.y += delta * GRAVITY

	var hvel = vel
	hvel.y = 0

	var target = dir

	if is_sprinting:
		target *= MAX_SPRINT_SPEED
	else:
		target *= MAX_SPEED

	var accel
	if dir.dot(hvel) > 0:
		if is_sprinting:
			accel = SPRINT_ACCEL
		else:
			accel = ACCEL
	else:
		accel = DEACCEL

	hvel = hvel.linear_interpolate(target, accel * delta)
	vel.x = hvel.x
	vel.z = hvel.z
	vel = move_and_slide(vel, Vector3(0, 1, 0), 0.05, 4, deg2rad(MAX_SLOPE_ANGLE))

#	for i in get_slide_count():
#		var collision = get_slide_collision(i)
#		if collision.collider.name == "Shopzone":
#			print ("something")


#		if collision.collider.name == "Test":
#			print ("something else")

func _input(event):
	if is_dead:
		return

	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotation_helper.rotate_x(deg2rad(event.relative.y * MOUSE_SENSITIVITY))
		self.rotate_y(deg2rad(event.relative.x * MOUSE_SENSITIVITY * -1))

		var camera_rot = rotation_helper.rotation_degrees
		camera_rot.x = clamp(camera_rot.x, -70, 70)
		rotation_helper.rotation_degrees = camera_rot

	if event is InputEventMouseButton and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if event.button_index == BUTTON_WHEEL_UP or event.button_index == BUTTON_WHEEL_DOWN:
			if event.button_index == BUTTON_WHEEL_UP:
				mouse_scroll_value += MOUSE_SENSITIVITY_SCROLL_WHEEL
			elif event.button_index == BUTTON_WHEEL_DOWN:
				mouse_scroll_value -= MOUSE_SENSITIVITY_SCROLL_WHEEL

			mouse_scroll_value = clamp(mouse_scroll_value, 0, WEAPON_NUMBER_TO_NAME.size() - 1)

			if changing_weapon == false:
				if reloading_weapon == false:
					var round_mouse_scroll_value = int(round(mouse_scroll_value))
					if WEAPON_NUMBER_TO_NAME[round_mouse_scroll_value] != current_weapon_name:
						changing_weapon_name = WEAPON_NUMBER_TO_NAME[round_mouse_scroll_value]
						changing_weapon = true
						mouse_scroll_value = round_mouse_scroll_value

func process_UI(delta):
	# Updates the player's score.
	$"HUD/UI/Panel-Score/Score".text = str(Globals.playerScore)
	$"HUD/UI/Panel-EnemyScore/EnemyScore".text = str(Globals.enemyScore)
	#UI Processing
	
	# Text that appears on the HUD.
	if current_weapon_name == "UNARMED" or current_weapon_name == "KNIFE":
		# First line: Health, second line: Grenades
		UI_status_label.text = "HEALTH: " + str(health)
	else:
		var current_weapon = weapons[current_weapon_name]
		# First line: Health, second line: weapon and ammo, third line: grenades
		UI_status_label.text = "HEALTH: " + str(health)

	if current_weapon_name == "UNARMED" or current_weapon_name == "KNIFE":
		# First line: Health, second line: Grenades
		UI_status_label2.text = current_grenade + ": " + str(grenade_amounts[current_grenade])
	else:
		var current_weapon = weapons[current_weapon_name]
		# First line: Health, second line: weapon and ammo, third line: grenades
		UI_status_label2.text = "AMMO: " + str(current_weapon.ammo_in_weapon) + "/" + str(current_weapon.spare_ammo) + \
				"\n" + current_grenade + ": " + str(grenade_amounts[current_grenade])

	if Input.is_action_just_pressed("ui_shop"):
		for i in get_slide_count():
			var collision = get_slide_collision(i)
			if collision.collider.name == "Shopzone":
				print ("something")
		#if Input.is_action_just_pressed("grab_object") and current_weapon_name == "UNARMED":
		
				POPUP_SCENE.visible = true
				shop_open = true
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
#			popup.get_node("Button_quit").connect("pressed", self, "popup_quit")
#			popup.connect("popup_hide", self, "popup_closed")
#			popup.get_node("Button_resume").connect("pressed", self, "popup_closed")

#			canvas_layer.add_child(popup)
#			popup.popup_centered()

#			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

#			get_tree().paused = true

	elif shop_open == true and Input.is_action_just_pressed("ui_shop_close"):
		POPUP_SCENE.visible = false
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# ---------------------------------
	# Reloading the weapon

func process_reloading(delta):
	if reloading_weapon == true:
		var current_weapon = weapons[current_weapon_name]
		if current_weapon != null:
			current_weapon.reload_weapon()
		reloading_weapon = false
	# ----------------------------------

	# ----------------------------------
	# Audio stuff
func create_sound(sound_name, position=null):
	globals.play_sound(sound_name, false, position)
	# ----------------------------------

	# ----------------------------------
	# Health pickups
func add_health(additional_health):
	health += additional_health
	health = clamp(health, 0, MAX_HEALTH)
	# ----------------------------------

	# ----------------------------------
	# Ammo pickups
func add_ammo(additional_ammo):
	if (current_weapon_name != "UNARMED"):
		if (weapons[current_weapon_name].CAN_REFILL == true):
			weapons[current_weapon_name].spare_ammo += weapons[current_weapon_name].AMMO_IN_MAG * additional_ammo
	# ----------------------------------

	# ----------------------------------
	# Grenade stuff
func add_grenade(additional_grenade):
	grenade_amounts[current_grenade] += additional_grenade
	grenade_amounts[current_grenade] = clamp(grenade_amounts[current_grenade], 0, 4)
	# ----------------------------------

	# ----------------------------------
	# Player hit by turret 
func bullet_hit(damage, bullet_hit_pos):
	health -= damage
	# ----------------------------------

func process_respawn(delta):

	# If we've just died
	if health <= 0 and !is_dead:
		$Body_CollisionShape.disabled = true
		$Feet_CollisionShape.disabled = true

		changing_weapon = true # Resets/Puts away weapon
		changing_weapon_name = "UNARMED"

		$HUD/Death_Screen.visible = true # Death screen overlay

		$HUD/Panel.visible = false # Hides UI
		$HUD/Crosshair.visible = false

		dead_time = RESPAWN_TIME
		is_dead = true

		if grabbed_object != null:
			grabbed_object.mode = RigidBody.MODE_RIGID
			grabbed_object.apply_impulse(Vector3(0, 0, 0), -camera.global_transform.basis.z.normalized() * OBJECT_THROW_FORCE / 2)

			grabbed_object.collision_layer = 1
			grabbed_object.collision_mask = 1

			grabbed_object = null

	if is_dead:
		dead_time -= delta

		var dead_time_pretty = str(dead_time).left(3)
		$HUD/Death_Screen/Label.text = "You died\n" + dead_time_pretty + " seconds till respawn"

		if dead_time <= 0:
			global_transform.origin = globals.get_respawn_position()

			$Body_CollisionShape.disabled = false
			$Feet_CollisionShape.disabled = false

			$HUD/Death_Screen.visible = false

			$HUD/Panel.visible = true
			$HUD/Crosshair.visible = true

			for weapon in weapons:
				var weapon_node = weapons[weapon]
				if weapon_node != null:
					weapon_node.reset_weapon()

			health = 100
			grenade_amounts = {"Grenade":2, "Sticky Grenade":2}
			current_grenade = "Grenade"

			is_dead = false
