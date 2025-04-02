extends CharacterBody3D

signal health_changed(health_value)

@onready var camera = $Camera3D
@onready var anim_player = $AnimationPlayer
@onready var muzzle_flash = $Camera3D/Pistol/MuzzleFlash
@onready var raycast = $Camera3D/RayCast3D
@onready var gunshot = $gunshot
@export var crouch_height : float = 1.5  # Crouched height
@export var standing_height : float = 2.5  # Standing height
@onready var ammo_counter = null
@onready var hitmarker = $CanvasLayer/HUD/Hitmarker  # Adjust path to match your scene
@onready var reticle = $CanvasLayer/HUD/Reticle


var is_crouching : bool = false
var bullet_spawn
var bullet_scene = preload("res://player_bullet.tscn")
var shoot_cooldown = 0.2
var can_shoot = true
var ammo = 16
var reload_time = 3
var max_health = 100
var current_health = max_health
var health:int = 100
var is_ready = false
var speed = 5.0
var gravity = 20.0
var is_reloading = false 
const JUMP_VELOCITY = 10.0


func take_damageP(amount) -> void:
	health -= amount
	print("damage taken")
	if health <= 0:
		print("Game Over!")
		# Reset the player's health and position
		health = max_health
		position = Vector3.ZERO
		# Emit the health_changed signal with the reset health value
		health_changed.emit(health)
		start_reload()
	else:
		# Emit the health_changed signal with the updated health value
		health_changed.emit(health)
	
#func die() -> void:
##	print("Player has died")
##	print(current_health)
	#position = Vector3.ZERO
	#current_health = max_health
	


func _enter_tree():
	set_multiplayer_authority(str(name).to_int())


func _ready():
	Global.player = self
	if not is_multiplayer_authority(): return
	bullet_spawn = get_node("Camera3D/bulletSpawn")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	camera.current = true
	# Find HUD in the world
	Global.player = self
	#print("Player _ready() called!")

	await get_tree().process_frame  # Wait a frame
	var hud = null

	while hud == null:
		hud = get_tree().get_first_node_in_group("hud")
		if hud:
			print("HUD found:", hud)
			hitmarker = hud.get_node_or_null("Hitmarker")

	camera.position.y = standing_height / 1.3

	ammo_counter = get_node("Camera3D/AmmoCounter")
	if ammo_counter:
		update_ammo_counter()
	else:
		is_ready = true
		print("ammo counte rnot foun")
		
	if is_ready and ammo_counter:
		update_ammo_counter()	
	

func update_ammo_counter():
	if ammo_counter:
		ammo_counter.text = str(ammo) + "/16"
	else:
		print("no label cuh")
	


func _unhandled_input(event):
	if not is_multiplayer_authority(): return
	
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * .005)
		camera.rotate_x(-event.relative.y * .005)
		camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2)
	
	if Input.is_action_just_pressed("shoot") and can_shoot and ammo > 0:
		shoot()
		anim_player.stop()
		anim_player.play("shoot")
		gunshot.play()
		muzzle_flash.restart()
		muzzle_flash.emitting = true
		can_shoot = false
		#and anim_player.current_animation != "shoot":
		await get_tree().create_timer(shoot_cooldown).timeout
		can_shoot = true
		#if raycast.is_colliding():
			#var hit_player = raycast.get_collider()
			#hit_player.receive_damage.rpc_id(hit_player.get_multiplayer_authority())

	# Detect the reload key (R key)
	if Input.is_action_just_pressed("reload") and not is_reloading and ammo < 16:
		start_reload()


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

#@rpc("any_peer")
#func receive_damage():
#	current_health -= 20
#	print("player health")
#	if current_health <= 0:
#		current_health == max_health
#		position = Vector3.ZERO
#		die()
#	health_changed.emit(current_health)

func _on_animation_player_animation_finished(anim_name):
	if anim_name == "shoot":
		anim_player.play("idle")
		
# Called every frame
func _process(delta):
	# Check if the player is holding shift to run
	# Speeds are subject to change
	if Input.is_action_pressed("player_run") and is_crouching == false:
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
	# If ammo is greater than 0, proceed with shooting
	if ammo > 0:
		var bullet = bullet_scene.instantiate()
		get_tree().root.add_child(bullet)
		bullet.global_transform = bullet_spawn.global_transform
		bullet.scale = Vector3(0.1, 0.1, 0.1)
		

		# Connect bullet collision to hitmarker function
		bullet.connect("enemy_hit", Callable(self, "show_hitmarker"))

		# Decrease ammo by 1
		ammo -= 1

		# Update the ammo counter
		update_ammo_counter()
	


func reset_ammo_with_delay() -> void:
	# Wait for the specified delay
	await get_tree().create_timer(reload_time).timeout
	
	# After the delay, reset ammo to 1
	ammo = 16



func start_reload():
	is_reloading = true
	if ammo_counter:
		ammo_counter.text = "RELOADING"  # Display reloading text
	# Play reload animation if applicable
	# anim_player.play("reload")

	await get_tree().create_timer(reload_time).timeout  # Wait for reload time

	ammo = 16  # Reset ammo after reload
	update_ammo_counter()  # Update the counter after reload
	is_reloading = false



func show_hitmarker():
	if hitmarker:
		if reticle:
			reticle.visible = false  # Hide reticle when hitmarker appears
#
		#print("Showing hitmarker!")
		hitmarker.visible = true
		await get_tree().create_timer(0.2).timeout  # Keep hitmarker for 0.2s
		hitmarker.visible = false
		
		if reticle:
			reticle.visible = true  # Show reticle again after hitmarker disappears
			
		#print("Hiding hitmarker!")
	#else:
		#print("ERROR: Hitmarker is NULL!")
