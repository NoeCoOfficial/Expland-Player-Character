@icon("res://Textures/Icons/Script Icons/32x32/character_edit.png")
extends CharacterBody3D


@export_group("Utility")
@export var inventory_opened_in_air := false
@export var speed: float
@export var GAME_STATE := "NORMAL"


@export_group("Gameplay")

@export_subgroup("Health")
@export var UseHealth := true
@export var MaxHealth := 100
@export var Health := 100

@export_subgroup("Other")
@export var Position := Vector3(0, 0, 0)


@export_group("Spawn")
@export var StartPOS := Vector3(0, 0, 0)
@export var ResetPOS := Vector3(0, 0, 0)

@export_subgroup("Fade_In")
@export var Fade_In := false
@export var Fade_In_Time := 1.0


@export_group("Input")
@export var Pause := true
@export var Reset := true
@export var Quit := true


@export_group("Visual")
@export_subgroup("Camera")
@export var FOV := 120.0
@export_subgroup("Crosshair")
@export var crosshair_size := Vector2(12, 12)


@export_group("View Bobbing")
@export var BOB_FREQ := 3.0
@export var BOB_AMP := 0.08
@export var BOB_SMOOTHING_SPEED := 3.0


@export_group("Mouse")
@export var SENSITIVITY := 0.001


@export_group("Physics")

@export_subgroup("Movement")
@export var WALK_SPEED := 5.0
@export var SPRINT_SPEED := 8.0
@export var JUMP_VELOCITY := 4.5

@export_subgroup("Crouching")
@export var CROUCH_JUMP_VELOCITY := 4.5
@export var CROUCH_SPEED := 3.0
@export var CROUCH_INTERPOLATION := 6.0

@export_subgroup("Gravity")
@export var gravity := 12.0


@export_group("Slide")
@export var SLIDE_START_SPEED := 10.0
@export var SLIDE_MIN_SPEED := 4.0
@export var SLIDE_MAX_TIME := 0.85
@export var SLIDE_FRICTION := 12.0
@export var SLIDE_STEER := 5.0
@export var SLIDE_HOP_BOOST := 1.05


@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var crosshair: Control = $Head/Camera3D/CrosshairCanvas/Crosshair


var wave_length := 0.0
var camera_base_pos := Vector3.ZERO

var was_on_floor := false

var is_sliding := false
var slide_time := 0.0
var slide_speed := 0.0
var slide_dir := Vector3.ZERO


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	camera_base_pos = camera.position


func _input(_event: InputEvent) -> void:
	if Quit and Input.is_action_just_pressed("Quit"):
		get_tree().quit()
	if Reset and Input.is_action_just_pressed("Reset"):
		if ResetPOS == Vector3(999, 999, 999):
			position = StartPOS
		else:
			position = ResetPOS


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		head.rotate_y(-event.relative.x * SENSITIVITY)
		camera.rotate_x(-event.relative.y * SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-90), deg_to_rad(90))


func _physics_process(delta: float) -> void:
	var on_floor := is_on_floor()
	var input_vec := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var wish_dir := (head.transform.basis * Vector3(input_vec.x, 0.0, input_vec.y)).normalized()
	var horizontal_speed := Vector3(velocity.x, 0.0, velocity.z).length()

	_update_crouch_scale(delta)

	if GAME_STATE == "DEAD":
		_stop_slide()
		velocity.x = lerp(velocity.x, 0.0, delta * 10.0)
		velocity.z = lerp(velocity.z, 0.0, delta * 10.0)
		move_and_slide()
		_update_view_bob(delta)
		was_on_floor = on_floor
		return

	if not on_floor:
		velocity.y -= gravity * delta

	if is_sliding and (not on_floor or Input.is_action_just_pressed("Jump")):
		if Input.is_action_just_pressed("Jump"):
			var boosted = max(horizontal_speed, SLIDE_MIN_SPEED) * SLIDE_HOP_BOOST
			velocity.y = JUMP_VELOCITY
			velocity.x = slide_dir.x * boosted
			velocity.z = slide_dir.z * boosted
		_stop_slide()

	if on_floor and (not is_sliding) and Input.is_action_just_pressed("Jump") and (not Input.is_action_pressed("Crouch")):
		velocity.y = JUMP_VELOCITY

	if on_floor and (not was_on_floor) and (not is_sliding):
		if Input.is_action_pressed("Crouch") and Input.is_action_pressed("Sprint") and wish_dir != Vector3.ZERO:
			_start_slide(wish_dir, max(horizontal_speed, SPRINT_SPEED))

	if on_floor and (not is_sliding):
		if Input.is_action_just_pressed("Crouch") and Input.is_action_pressed("Sprint") and wish_dir != Vector3.ZERO and horizontal_speed > WALK_SPEED:
			_start_slide(wish_dir, max(horizontal_speed, SLIDE_START_SPEED))

	if is_sliding:
		_update_slide(delta, wish_dir)
	else:
		_update_walk(delta, wish_dir, on_floor)

	move_and_slide()
	_update_view_bob(delta)
	was_on_floor = is_on_floor()


func _update_walk(delta: float, wish_dir: Vector3, on_floor: bool) -> void:
	if Input.is_action_pressed("Sprint") and (not Input.is_action_pressed("Crouch")):
		speed = SPRINT_SPEED
	elif Input.is_action_pressed("Crouch"):
		speed = CROUCH_SPEED
	else:
		speed = WALK_SPEED

	if on_floor:
		if wish_dir != Vector3.ZERO:
			velocity.x = wish_dir.x * speed
			velocity.z = wish_dir.z * speed
		else:
			velocity.x = lerp(velocity.x, 0.0, delta * 10.0)
			velocity.z = lerp(velocity.z, 0.0, delta * 10.0)
	else:
		velocity.x = lerp(velocity.x, wish_dir.x * speed, delta * 3.0)
		velocity.z = lerp(velocity.z, wish_dir.z * speed, delta * 3.0)


func _start_slide(dir: Vector3, start_speed: float) -> void:
	is_sliding = true
	slide_time = 0.0
	slide_dir = dir
	slide_speed = max(start_speed, SLIDE_START_SPEED)
	velocity.x = slide_dir.x * slide_speed
	velocity.z = slide_dir.z * slide_speed


func _stop_slide() -> void:
	is_sliding = false
	slide_time = 0.0
	slide_speed = 0.0
	slide_dir = Vector3.ZERO


func _update_slide(delta: float, wish_dir: Vector3) -> void:
	slide_time += delta

	if wish_dir != Vector3.ZERO:
		slide_dir = slide_dir.slerp(wish_dir, clamp(delta * SLIDE_STEER, 0.0, 1.0)).normalized()

	slide_speed = max(slide_speed - (SLIDE_FRICTION * delta), 0.0)
	velocity.x = slide_dir.x * slide_speed
	velocity.z = slide_dir.z * slide_speed

	if (not Input.is_action_pressed("Crouch")) or slide_speed < SLIDE_MIN_SPEED or slide_time >= SLIDE_MAX_TIME:
		_stop_slide()


func _update_crouch_scale(delta: float) -> void:
	var target := 1.0
	if Input.is_action_pressed("Crouch") or is_sliding:
		target = 0.5
	scale.y = lerp(scale.y, target, CROUCH_INTERPOLATION * delta)


func _update_view_bob(delta: float) -> void:
	var h_speed := Vector3(velocity.x, 0.0, velocity.z).length()
	var moving := is_on_floor() and h_speed > 0.1

	if moving:
		wave_length += delta * h_speed
		camera.position = camera_base_pos + _headbob(wave_length)
	else:
		camera.position = camera.position.lerp(camera_base_pos, delta * BOB_SMOOTHING_SPEED)


func _headbob(time: float) -> Vector3:
	return Vector3(0.0, sin(time * BOB_FREQ) * BOB_AMP, 0.0)


func _process(_delta: float) -> void:
	camera.fov = FOV
	crosshair.size = crosshair_size
