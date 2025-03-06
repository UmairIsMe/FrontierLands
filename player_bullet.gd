extends Area3D

var speed: float = 50.0
var damage: int = 1
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	global_transform.origin -= transform.basis.z.normalized() * speed * delta
	
func _on_body_entered(body):
	if body.has_method("take_damage"):
		print("ow")
		body.take_damage(damage)
		destroy()



func destroy():
	queue_free()
