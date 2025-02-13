extends CharacterBody3D

@onready var nav_agent = $NavigationAgent3D
var SPEED = 7.0
const JUMP_VELOCITY = 4.5
@export var bullet_scene: PackedScene
@export var shooting_offset: Vector3 = Vector3(0, 1, 3)  # Adjust where bullets should spawn

var shoot_timer: Timer

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")



func update_target_location (target_location):
	nav_agent.set_target_position(target_location)

func _physics_process(_delta):
	var current_location = global_transform.origin
	var next_location = nav_agent.get_next_path_position()
	look_at(next_location) # Enemy will turn to face player
	
	# Vector Maths
	var new_veloicty = (next_location-current_location).normalized() * SPEED

	velocity = new_veloicty
	
	move_and_slide()


func shoot_bullet():
	# Create the bullet instance
	var bullet_instance = bullet_scene.instantiate()
# Position the bullet in front of the enemy
	bullet_instance.global_transform.origin = global_transform.origin + shooting_offset
	# Add bullet to the scene
	get_parent().add_child(bullet_instance)


func _on_timer_timeout():
	shoot_bullet()
