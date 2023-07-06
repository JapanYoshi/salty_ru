extends ColorRect

var frame: int = 0
var delta_cumul: float = 0.0
var paused_times: int = 0
var device: int = -1
const framerate = 30.0
var ending: bool = false

var ep: Control
onready var bg = $Bg
onready var anim = $AnimationPlayer
onready var number_label = $NprContainer/NinePatchRect/Sprite/Label
onready var title_label = $NprContainer/NinePatchRect/Label
onready var count_label = $NprContainer/NinePatchRect/Label2

# Called when the node enters the scene tree for the first time.
func _ready():
	hide()
	ep = get_parent()
	C.connect("gp_button", self, "_gp_button")
	C.connect("gp_button_paused", self, "_gp_button_paused")
	C.connect("gp_axis_paused", self, "_gp_axis_paused")
	$NprContainer/HBoxContainer/HSlider.value = R.get_settings_value("overall_volume")
	get_tree().connect("screen_resized", self, "_on_size_changed")


const base_resolution = Vector2(1280, 720)
func _on_size_changed():
	var resolution = get_viewport_rect().size
	$NprContainer.rect_scale = Vector2.ONE * min(
		resolution.y / base_resolution.y,
		resolution.x / base_resolution.x
	)


func _process(delta):
	if !visible: return
	_move_randomly(delta)


func _move_randomly(delta):
	delta_cumul += delta * framerate
	if delta_cumul >= 1.0:
		delta_cumul -= 1.0
		frame += 1
		bg.rect_position = -256 * Vector2(fmod(frame * 355 / 113.0, 1.0), fmod(frame * 127 / 360.0, 1))


func pause_modal(player_number, device_index):
	if ep.penalize_pausing:
		paused_times += 1
		if paused_times >= 3:
			var rand = R.rng.randf()
			var thres = (paused_times - 3) / 5.0
			if rand < thres and not("no_pause_penalty" in R.get_settings_value("cheat_codes_active")):
				print("too many pauses")
				ep.too_many_pauses()
				C.disconnect("gp_button", self, "_gp_button")
				return
	device = device_index
	if player_number == -1:
		$NprContainer/NinePatchRect/Sprite.hide()
	else:
		$NprContainer/NinePatchRect/Sprite.show()
		number_label.set_text("%d" % (player_number + 1))
	if "no_pause_penalty" in R.get_settings_value("cheat_codes_active"):
		match paused_times:
			0:
				count_label.set_text("You have the “infinite pauses” cheat code on.")
			1:
				count_label.set_text("You paused once this game.")
			2:
				count_label.set_text("You paused twice this game.")
			3:
				count_label.set_text("Normally, the third pause onward may get you DQ’d.")
			8:
				count_label.set_text("Normally, the 8th pause onward is a guaranteed DQ.")
			_:
				count_label.set_text("Abusing the cheat code, you paused %d times." % paused_times)
	else:
		match paused_times:
			0:
				count_label.set_text("What now, contestant?")
			1:
				count_label.set_text("Don’t pause too much during a question.")
			2:
				count_label.set_text("Busy? Come back soon.")
			3:
				count_label.set_text("You’re being a bit suspicious right now.")
			4:
				count_label.set_text("The host is getting upset.")
			5:
				count_label.set_text("You’re on thin ice.")
			_:
				count_label.set_text("Dude, why are you doing this?")
	_on_size_changed()
	show()
	anim.play("show")
	get_tree().paused = true


func resume():
	if anim.get_playing_speed() or !visible: return
	anim.play("hide")


func quit():
	if anim.get_playing_speed() or !visible: return
#	if Ws.connected:
#		Ws.close_room()
#		Ws._disconnect(1000, "Game quit from pause menu.")
	S.stop_voice()
	get_tree().change_scene("res://Title.tscn")
	get_tree().paused = false


func _gp_button(index, button, pressed):
	if ending: return;
	# dont accept during an animation
	if anim.get_playing_speed(): return
	# pause button?
	if button == 6 and pressed:
		accept_event()
		if visible:
			if index == device:
				resume()
		else:
			var i = -1
			for p in R.players:
				if p.device_index == index:
					i = p.player_number
			pause_modal(i, index)
		return


func _gp_button_paused(index, button, pressed):
	# other buttons?
	if index != device or !pressed: return
	if button == 5 or button == 6:
		accept_event()
		resume()
		return;
	elif button == 4:
		accept_event()
		quit()
	elif button == 14:
		_change_volume(-1)
		accept_event()
	elif button == 15:
		_change_volume(1)
		accept_event()
	return;


var last_axis_value: float = 0.0
const axis_value_thres: float = 0.5
func _gp_axis_paused(index, axis, value):
	# other buttons?
	if index != device or axis != 0: return
	if last_axis_value < axis_value_thres and axis_value_thres <= value:
		# cursor right
		last_axis_value = value
		_change_volume(1)
		accept_event()
		return
	if value <= -axis_value_thres and -axis_value_thres < last_axis_value:
		# cursor left
		last_axis_value = value
		_change_volume(-1)
		accept_event()
		return
	if (last_axis_value <= -axis_value_thres and -axis_value_thres < value) or\
	(last_axis_value >= axis_value_thres and axis_value_thres > value):
		# cursor center
		last_axis_value = value
		accept_event()
		return


func _change_volume(by: float):
	print("changed volume via controller input")
	$NprContainer/HBoxContainer/HSlider.value += by


func _on_AnimationPlayer_animation_finished(anim_name):
	if anim_name == "hide":
		hide()
		get_tree().paused = false


## Hard-codes the maximum of 15 so that might be an issue later if I change it
func _on_HSlider_value_changed(value):
	if !visible: return
	print("_on_HSlider_value_changed(", value, ")")
	R.set_settings_value("overall_volume", value)
	var v = float(value) / 15.0
	S.set_overall_volume(v)
	$VolumeSound.pitch_scale = v + 1.0
	$VolumeSound.play()
