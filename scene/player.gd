extends CharacterBody2D
class_name Player

## NOTE Increasing snap_length on the character_body_2d allows it to snap to slopes better
## as it slides, constant_speed allows it to slide at the same speed regardless or angle instead of faster
## NOTE AnimationPlayer is recommended as it allows to add custom keys on the animation, changing color, etc
## see slide animation for example!

@onready var sprite: Sprite2D = $sprite
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var dust_particles: CPUParticles2D = $dust_particles

#Global Variables

const SPEED : float = 200.0 #movement speed
@export var jump_velocity : float = -400.0 #jump height

#Sliding Variables
@export var slide_initial_speed: float = 500.0 #Initial slide speed on push
@export var slide_deceleration: float = 600.0 #Slide Deceleration
@export var slide_stop_threshold: float = 100.0#slide stop
@export var slide_cooldown: float = 1.5 #CD on slide

var is_sliding: bool = false
var can_slide: bool = true

@onready var default_shape : CollisionShape2D = $default_shape
@onready var slide_shape : CollisionShape2D = $slide_shape
@onready var sliding_cooldown_timer : Timer = $slide_timer

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	handle_gravity(delta)
	handle_jump()
	handle_slide_logic(delta)
	## Collisions have to switch AFTER sliding, otherwise if next to a wall, they wont have time
	## to change and thus getting you stuck 
	handle_player_collison_shapes()
	player_run()
	move_and_slide()

func handle_gravity(delta):
	if not is_on_floor():
		velocity.y += get_gravity().y * delta
		if velocity.y >= 0: 
			animation_player.play("falling")
		else:
			animation_player.play("jump")
	else:
		velocity.y = 0
		## Allows it to keep sliding after falling from a slide
		if is_sliding:
			if animation_player.current_animation != "slide":
				animation_player.play("slide_loop")

func handle_jump():
	if is_sliding:
		return
	## Jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

func handle_player_collison_shapes():
	if is_sliding and slide_shape.disabled:
		default_shape.disabled = true
		slide_shape.disabled = false
	elif not is_sliding and default_shape.disabled:
		default_shape.disabled = false
		slide_shape.disabled = true

func handle_slide_logic(delta):
	## If sliding, deaccelerate, then check if it should stop already or not!
	if is_sliding:
		velocity.x -= slide_deceleration * delta * sign(velocity.x)
		if abs(velocity.x) <= slide_stop_threshold:
			is_sliding = false
			stop_sliding()
			return
	
	## Start a slide
	if is_on_floor() and Input.is_action_pressed("down") and can_slide:
		if Input.is_action_just_pressed("ability"): 
			if not is_sliding:
				is_sliding = true
				can_slide = false
				## Move towards the facing direction NOT velocity.x
				## this was the main issue with slide not working, while idle, velocity is ALWAYS 0, so it was
				## sliding for a 0 velocity and thus never doing so
				velocity.x = slide_initial_speed * get_direction()
				dust_particles.direction.x = get_direction() * -1
				
				animation_player.play("slide")

## Gets which side the character is currently looking towards, regardless of control input
func get_direction() -> int:
	if sprite.flip_h == true:
		return -1
	else:
		return 1

func stop_sliding():
	is_sliding = false
	sliding_cooldown_timer.start(slide_cooldown)

func player_run():
	## If you're NOT sliding, move or slow down
	var direction = Input.get_axis("left","right")
	if not is_sliding:
		if direction:
			velocity.x = direction * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED * 0.5)
	
		## Idle or not!
		if is_on_floor():
			if velocity == Vector2.ZERO:
				animation_player.play("idle")
			else:
				animation_player.play("run")
	
	## Flip the sprite
	if direction != 0:
		sprite.flip_h = false if direction > 0 else true

func _on_slide_timer_timeout() -> void:
	can_slide = true
