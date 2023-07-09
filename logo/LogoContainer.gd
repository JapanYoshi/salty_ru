extends Control
onready var anim: AnimationPlayer = $AnimationPlayer
var title_loader: ResourceInteractiveLoader
var title: PackedScene
var ready_to_play_intro: bool = false
# Animated logo for hai!touch Studios.

# Called when the node enters the scene tree for the first time.
func _ready():
	print("LogoContainer._ready()")
	title_loader = ResourceLoader.load_interactive("res://Title.tscn")
	_on_size_changed()
	get_viewport().connect("size_changed", self, "_on_size_changed")
	anim.play("rating_fadein")
	call_deferred("_check_title_loader")


func _check_title_loader():
	if title_loader.poll() != ERR_FILE_EOF:
		call_deferred("_check_title_loader")
	else:
		title = title_loader.get_resource()
		get_parent().get_node("RatingCover").hide()
		ready_to_play_intro = true


func _on_size_changed():
	var resolution = get_viewport_rect().size
	var scale = min(
		resolution.x / 1280,
		resolution.y / 720
	)
	rect_scale = Vector2.ONE * scale / 1.5 # 1080p logo in 720p screen
	
# Called when the logo is finished animating.
# Also called when the user skips the logo.
func _on_AnimationPlayer_animation_finished(anim_name):
	if anim_name == "fadeout":
		anim.play("haitouch")
	elif anim_name == "haitouch":
		# dummy animation; the real animation is in the viewport
		anim.play("thebox")
		$TheBoxContainer.show()
		$TheBoxV/s/AnimationPlayer.play("thebox")
	elif anim_name == "thebox":
		$TheBoxV/s/AnimationPlayer.stop(false)
		$TheBoxContainer.hide()
		anim.play("godot")
	elif anim_name == "godot":
		get_tree().change_scene_to(title)

# Called when the user skips the logo.
func skip():
	var anim_name = anim.current_animation
	if anim_name == "":
		S.play_sfx("key_press")
		anim.play("fadeout")
	elif anim_name == "fadeout":
		pass
	else:
		if anim.get_current_animation_position() > 0.25:
			anim.seek(100,true)
			_on_AnimationPlayer_animation_finished(anim_name)

func _input(event):
	if ready_to_play_intro and "pressed" in event and event.pressed:
		if Input.is_action_pressed("ui_accept"):
			skip()
		elif event is InputEventMouseButton:
			if event.button_index == BUTTON_LEFT:
				skip()
