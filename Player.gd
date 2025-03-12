extends CharacterBody3D

signal health_changed(health_value)

@onready var camera = $Camera3D
@onready var anim_player = $AnimationPlayer
@onready var muzzle_flash = $Camera3D/Pistol/MuzzleFlash
@onready var raycast = $Camera3D/RayCast3D
@onready var gunshot = $gunshot
@export var crouch_height : float = 1.5  # Crouched height
@export var standing_height : float = 2.5  # Standing height

#Crouch and standing heights can be changed at any time
@onready var health_bar: ProgressBar = $HealthBar

var is_crouching : bool = false
var bulletSpawn
var bulletScene = preload("res://player_bullet.tscn")
var shootCooldown = 0.2
var can_shoot = true

var max_health = 100
var current_health: int = max_health


var speed = 5.0
const JUMP_VELOCITY = 10.0



# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = 20.0

func take_damage(amount) -> void:
	current_health -= amount
	current_health = clamp(current_health, 0, max_health)
	
	if health_bar:
		health_bar.value = current_health
		
	if current_health <= 0:
		die()
	
func die() -> void:
	print("Player has died")


func _enter_tree():
	set_multiplayer_authority(str(name).to_int())

func _ready():
	if not is_multiplayer_authority(): return
	bulletSpawn = get_node("Camera3D/bulletSpawn")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	camera.current = true
	
	camera.position.y = standing_height / 1.3

func _unhandled_input(event):
	if not is_multiplayer_authority(): return
	
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * .005)
		camera.rotate_x(-event.relative.y * .005)
		camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2)
	
	if Input.is_action_just_pressed("shoot") and can_shoot:
		shoot()
		can_shoot = false
		#and anim_player.current_animation != "shoot":
		await get_tree().create_timer(shootCooldown).timeout
		can_shoot = true
		play_shoot_effects.rpc()
		if raycast.is_colliding():
			var hit_player = raycast.get_collider()
			hit_player.receive_damage.rpc_id(hit_player.get_multiplayer_authority())
			

func _physics_process(delta):
	if not is_multiplayer_authority(): return
	
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle Jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir = Input.get_vector("left", "right", "up", "down")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	if anim_player.current_animation == "shoot":
		pass
	elif input_dir != Vector2.ZERO and is_on_floor():
		anim_player.play("move")
	else:
		anim_player.play("idle")

	move_and_slide()

@rpc("call_local")
func play_shoot_effects():
	anim_player.stop()
	anim_player.play("shoot")
	gunshot.play()
	muzzle_flash.restart()
	muzzle_flash.emitting = true

@rpc("any_peer")
func receive_damage():
	current_health -= 1
	if current_health <= 0:
		current_health = 3
		position = Vector3.ZERO
	health_changed.emit(current_health)

func _on_animation_player_animation_finished(anim_name):
	if anim_name == "shoot":
		anim_player.play("idle")
		
# Called every frame
func _process(delta):
	# Check if the player is holding shift to run
	# Speeds are subject to change
	if Input.is_action_pressed("player_run"):
		speed = 12.0
	elif Input.is_action_just_pressed("ui_crouch"):
		print("Crouch")
		toggle_crouch()
		speed = 3.5
		if is_crouching:
			camera.position.y = crouch_height / 2.0
		else:
			camera.position.y = standing_height / 1.3

	else:
		speed = 5.0

func toggle_crouch():
	is_crouching = !is_crouching

func shoot():
	var bullet = bulletScene.instantiate()
	get_tree().root.add_child(bullet)
	bullet.global_transform = bulletSpawn.global_transform
	bullet.scale = Vector3(0.1, 0.1, 0.1)
