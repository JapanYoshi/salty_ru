extends Control

var menu_root: Control
var p_count = 0 # number of players
var room_full: bool = false
var signup_now: Dictionary
var signup_queue: Array = []
var used_ids: Array = []
onready var signup_modal = $SignupModal
var signup_box = preload("res://SignupBox.tscn")
var room_code: String = ""
var room_code_hidden: bool = true

func _ready():
	update_loading_progress(0, 13, -1)
	R.rng.randomize()
# warning-ignore:return_value_discarded
	C.connect("gp_button", self, "_gp_button")
	$LoadingIndicator/LoadingPanel.hide()
	$MouseMask.hide()
	R.players = []; signup_now = {}; signup_queue = []; used_ids = [];
	p_count = 0
	$Instructions/SignupOnline.self_modulate = Color(1, 1, 1, 0.3)
	$Instructions/SignupOnline/RoomCode2.set_text("")
	$Instructions/SignupOnline/ReadAloud.set_text("")
	$Instructions/SignupOnline/RoomCode.set_text("")
	$Instructions/SignupOnline/ShowHide.set_text("")
	if R.get_settings_value("room_openness") != 0:
		$Instructions/SignupOnline/host.set_text("Connecting to server...")
#		Ws.connect('connected', self, "server_connected", [], CONNECT_ONESHOT)
#		Ws.connect('disconnected', self, "server_failed", [], CONNECT_ONESHOT)
#		Ws.connect('player_requested_nick', self, "give_player_nick")
#		Ws._connect()
		Fb._init_firebase()
		yield(Fb, "finished")
		server_connected_result(Fb.db_ready)
	else:
		$Instructions/SignupOnline/host.set_text("Online controllers are turned off because\n“Room openness” is set to “no room”.")

func server_connected_result(success: bool):
	if success:
		server_connected()
	else:
		server_failed()

func server_failed():
#	Ws.disconnect('connected', self, "server_connected")
	$Instructions/SignupOnline.self_modulate = Color(0.5, 0.5, 0.5, 0.5)
	$Instructions/SignupOnline/host.set_text("Could not connect to server.")
	$Instructions/SignupOnline/RoomCode2.set_text("Local play still works, though!")

func server_connected():
#	Ws.disconnect('disconnected', self, "server_failed")
	$Instructions/SignupOnline.self_modulate = Color(1, 1, 1, 0.3)
	# Ws.websocket_url
	$Instructions/SignupOnline/host.set_text("Посетите «haitouch.ga/lya»")
	$Instructions/SignupOnline/RoomCode2.set_text("Opening room...")
	$Instructions/SignupOnline/RoomCode.set_text("")
#	Ws.connect("room_opened", self, "room_opened", [], CONNECT_ONESHOT)
#	Ws.connect('disconnected', self, "server_failed", [], CONNECT_ONESHOT)
	Fb.try_room(self, "room_tried")

func room_tried(success: bool):
	if success:
		room_code = Fb.room_code
#		self.connect("tree_exited", Ws, "close_room")
		$Instructions/SignupOnline.self_modulate = Color(1, 1, 1, 1.0)
		$Instructions/SignupOnline/RoomCode2.set_text("и введите код комнаты:")
		room_code_hidden = !R.get_settings_value("hide_room_code")
		toggle_show_room_code()
		$Instructions/SignupOnline/ReadAloud.set_text("Shift/Select: read room code aloud")
# warning-ignore:return_value_discarded
		Fb.connect("player_joined", self, 'remote_queue')
	else:
		room_code = ""
		$Instructions/SignupOnline.self_modulate = Color(0.5, 0.2, 0.2, 0.5)
		$Instructions/SignupOnline/RoomCode2.set_text("Could not open room.")
	pass

func toggle_show_room_code():
	if room_code != "":
		if room_code_hidden:
			$Instructions/SignupOnline/ShowHide.set_text("Пробел/㍙: hide room code")
			$Instructions/SignupOnline/RoomCode.set_text(room_code)
		else:
			$Instructions/SignupOnline/ShowHide.set_text("Пробел/㍙: show room code")
			$Instructions/SignupOnline/RoomCode.set_text("????")
		room_code_hidden = !room_code_hidden

# How many takes there are for each line/letter.
const intro_takes: int = 5
const hidden_takes: int = 4
const cancel_takes: int = 3
const letter_takes_normal: int = 3
const letter_takes_final: int = 2
var room_code_cancelled: bool = false
var room_code_being_read: bool = false
var room_code_read_count: int = 0
var room_code_hidden_count: int = 0
onready var rc_player = $AudioStreamPlayer
onready var bgm_tween = $AudioStreamPlayer/Tween
onready var bgm_bus = AudioServer.get_bus_index("BGM")
onready var init_bgm_vol = AudioServer.get_bus_volume_db(bgm_bus)
func _set_bgm_volume(db: float):
	AudioServer.set_bus_volume_db(bgm_bus, db)

func duck_bgm_volume(enabled: bool):
	bgm_tween.stop_all()
	bgm_tween.interpolate_method(
		self, "_set_bgm_volume",
		AudioServer.get_bus_volume_db(bgm_bus),
		min(-16.0, init_bgm_vol) if enabled else init_bgm_vol,
		0.35
	)
	bgm_tween.start()

func read_room_code():
	if room_code == "" or bgm_tween.is_active(): return
	if room_code_being_read:
		var stream_loader = ResourceLoader.load_interactive(
			"res://audio/voice/rc_cancel_%02d.wav" %\
			posmod(room_code_read_count + room_code_hidden_count, cancel_takes)
		)
		$Instructions/SignupOnline/ReadAloud.set_text("Shift/Select: read room code aloud")
		room_code_being_read = false
		room_code_cancelled = true
		rc_player.stop()
		while stream_loader.poll() != ERR_FILE_EOF:
			yield(get_tree().create_timer(0.05), "timeout")
		rc_player.stream = stream_loader.get_resource()
		rc_player.play()
		yield(rc_player, "finished")
		if !room_code_cancelled: return
		duck_bgm_volume(false)
		yield(bgm_tween, "tween_all_completed")
		pass # cancel reading
	else:
		$Instructions/SignupOnline/ReadAloud.set_text("Shift/Select: cancel reading aloud")
		room_code_being_read = true
		room_code_cancelled = false
		duck_bgm_volume(true)
		yield(bgm_tween, "tween_all_completed")
		if room_code_hidden:
			var stream_loader = ResourceLoader.load_interactive(
				"res://audio/voice/rc_hidden_%02d.wav" %\
				posmod(room_code_hidden_count, hidden_takes)
			)
			while stream_loader.poll() != ERR_FILE_EOF:
				yield(get_tree().create_timer(0.05), "timeout")
			rc_player.stream = stream_loader.get_resource()
			room_code_hidden_count += 1
			rc_player.play()
			yield(rc_player, "finished")
			room_code_being_read = false
		else:
			var line_streams = [
				ResourceLoader.load_interactive(
					"res://audio/voice/rc_intro_%02d.wav" % (
						intro_takes - 1\
						if room_code_read_count >= intro_takes\
						else room_code_read_count
					)
				)
			]
			yield(get_tree(), "idle_frame")
			for i in range(3):
				line_streams.push_back(
					ResourceLoader.load_interactive(
					"res://audio/voice/rc_letter_normal_%s_%02d.wav" % [
						room_code[i].to_lower(),
						posmod(room_code_read_count + i, letter_takes_normal)
					])
				)
				yield(get_tree(), "idle_frame")
			line_streams.push_back(
				ResourceLoader.load_interactive(
					"res://audio/voice/rc_letter_final_%s_%02d.wav" % [
						room_code[3].to_lower(),
						posmod(room_code_read_count, letter_takes_final)
					]
				)
			)
			while line_streams[0].poll() != ERR_FILE_EOF:
				yield(get_tree().create_timer(0.05), "timeout")
			rc_player.stream = line_streams[0].get_resource()
			room_code_read_count += 1
			rc_player.play()
			yield(rc_player, "finished")
			if room_code_cancelled: return
			for i in range(1, len(line_streams)):
				while line_streams[i].poll() != ERR_FILE_EOF:
					yield(get_tree().create_timer(0.05), "timeout")
				rc_player.stream = line_streams[i].get_resource()
				rc_player.play()
				yield(get_tree().create_timer(0.8), "timeout")
				if room_code_cancelled: return
		duck_bgm_volume(false)
		yield(bgm_tween, "tween_all_completed")
		if room_code_cancelled: return
		room_code_being_read = false
		$Instructions/SignupOnline/ReadAloud.set_text("Shift/Select: read room code aloud")

# Just the remote game start thing. Since it's remote, "pressed" is always true.
func _gp_button(player: int, button: int, _pressed: bool):
	if len(R.players) > 0\
	and R.players[0].device == C.DEVICES.REMOTE\
	and R.get_settings_value("remote_start")\
	and R.players[0].device_index == player\
	and button == 5:
		start_game()

# Check for controllers that haven't signed up yet.
func _input(e):
	if $MouseMask.visible: return
	if len(signup_now): return
	if e is InputEventJoypadButton:
		var lookup = C.lookup_button(C.DEVICES.GAMEPAD, e.device, e.button_index)
		print(lookup)
		if e.button_index in [JOY_L, JOY_R, JOY_L2, JOY_R2]:
			if lookup.player == -1:
				# no match
				match e.button_index:
					JOY_L:
						if Input.is_joy_button_pressed(e.device, JOY_R):
							print("SIGNUP QUEUED")
							gp_queue(e.device, 0)
							
						elif Input.is_joy_button_pressed(e.device, JOY_L2):
							print("SIGNUP QUEUED")
							gp_queue(e.device, 1)
					JOY_R:
						if Input.is_joy_button_pressed(e.device, JOY_L):
							print("SIGNUP QUEUED")
							gp_queue(e.device, 0)
						elif Input.is_joy_button_pressed(e.device, JOY_R2):
							print("SIGNUP QUEUED")
							gp_queue(e.device, 2)
					JOY_L2:
						if Input.is_joy_button_pressed(e.device, JOY_L):
							print("SIGNUP QUEUED")
							gp_queue(e.device, 1)
					JOY_R2:
						if Input.is_joy_button_pressed(e.device, JOY_R):
							print("SIGNUP QUEUED")
							gp_queue(e.device, 2)
		else:
			# check if anyone's signing up
			if e.pressed and (
				e.device == 0 and len(signup_now) == 0
			):
				if lookup.button == 5 and (
					len(R.players) > 0 and len(signup_now) == 0 and len(signup_queue) == 0
				):
					if (
						R.players[0].device == C.DEVICES.GAMEPAD and R.players[0].device_index == lookup.player
					):
						start_game()
				elif e.button_index == JOY_DS_B:
					menu_root.back()
				elif e.button_index == JOY_DS_X:
					toggle_show_room_code()
				elif e.button_index == JOY_SELECT:
					read_room_code()
	elif e is InputEventKey:
		var sc = e.physical_scancode
		if e.pressed:
			if sc == KEY_ESCAPE:
				menu_root.back()
			# This is a hacky workaround caused by the fact that
			# "physical scancode" has been backported from Godot 4,
			# but not "is physical key pressed".
			# The workaround involves creating 8 individual input actions.
			if sc == KEY_Q and Input.is_action_pressed("signup0b")\
			or sc == KEY_E and Input.is_action_pressed("signup0"):
				kb_queue(0)
			elif sc == KEY_F and Input.is_action_pressed("signup1b")\
			or sc == KEY_H and Input.is_action_pressed("signup1"):
				kb_queue(1)
			elif sc == KEY_U and Input.is_action_pressed("signup2b")\
			or sc == KEY_O and Input.is_action_pressed("signup2"):
				kb_queue(2)
			elif sc == KEY_KP_7 and Input.is_action_pressed("signup3b")\
			or sc == KEY_KP_9 and Input.is_action_pressed("signup3"):
				kb_queue(3)
			elif sc == KEY_ENTER or sc == KEY_KP_ENTER:
				# check if anyone's signing up
				if len(R.players) > 0 and len(signup_now) == 0 and len(signup_queue) == 0:
					start_game()
			elif sc == KEY_SPACE:
				# check if anyone's signing up
				if len(signup_now) == 0:
					toggle_show_room_code()
			elif sc == KEY_SHIFT:
				if len(signup_now) == 0:
					read_room_code()

func gp_queue(device_number: int, side: int):
	print("SIGNUP QUEUED")
	# check if room is full
	if room_full: return
	# if it already has a slot number, it just returns that
	var input_slot_number = C.add_controller(C.DEVICES.GAMEPAD, device_number, side)
	if input_slot_number in used_ids:
		return
	used_ids.append(input_slot_number)
	signup_queue.append(
		{
			"type": C.DEVICES.GAMEPAD,
			"device_number": device_number,
			"input_slot_number": input_slot_number,
			"player_number": p_count,
			"side": side,
			"censored": false,
		}
	)
	p_count += 1
	# check if the room is not full (8 players signed up + signing up + queued)
	check_full()

func kb_queue(input_slot_number):
	# check if someone's currently signing up on keyboard
	if len(signup_now) > 0 and\
	signup_now.type == C.DEVICES.KEYBOARD:
		return
	# check if the player's already signed up
	for p in R.players:
		if p.device == C.DEVICES.KEYBOARD and p.device_index == input_slot_number:
			return
	# check if room is full
	if room_full: return
	if input_slot_number in used_ids:
		return
	used_ids.append(input_slot_number)
	signup_queue.append({
		"type": C.DEVICES.KEYBOARD,
		"device_number": input_slot_number,
		"input_slot_number": input_slot_number,
		"player_number": p_count,
		"side": 0,
		"censored": false,
	})
	p_count += 1
	accept_event()
	check_full()

func remote_queue(data):
	if data.name in used_ids:
		return
	used_ids.append(data.name)
	if !room_full:
		# join as player
		signup_queue.append({
			"type": C.DEVICES.REMOTE,
			"player_number": p_count,
			"remote_device_name": data.name,
			"name": data.nick,
			"side": 0,
			"censored": false,
		})
		p_count += 1
		accept_event()
		check_full()
	else:
		R.audience_join(data)

func check_full():
	# R.get_settings_value("room_size") is in range 0 - 7. Add 1 to get the actual player count.
	var total_players: int = len(R.players) + len(signup_now) + len(signup_queue);
#	var total_players: int = len(R.players) + len(signup_queue);
	print("DEBUG Player Count Check", total_players, "/", R.get_settings_value("room_size") + 1)
	if total_players >= R.get_settings_value("room_size") + 1:
		$TouchButton.hide()
		room_full = true;
	else:
		room_full = false;
	print("DEBUG Player Count Check room_full=", room_full)

# Just runs every frame regardless of how long it took
func _process(_delta):
	if (
		len(signup_now) == 0 # checking if the dictionary is empty
	and
		len(signup_queue) > 0
	):
		start_signup()

func start_signup():
	if len(R.players) >= 1 + R.get_settings_value("room_size"):
		return
	signup_now = signup_queue.pop_front()
	if signup_now.type == C.DEVICES.GAMEPAD:
		signup_modal.start_setup_gp(
			signup_now.device_number,
			signup_now.input_slot_number,
			signup_now.player_number,
			signup_now.side
		)
		S.play_sfx("menu_signout")
		S.play_track(0, 0)
		S.play_track(1, 1)
		S.play_track(2, 0)
	elif signup_now.type == C.DEVICES.KEYBOARD:
		signup_modal.start_setup_kb(
			signup_now.player_number,
			signup_now.input_slot_number
		)
		S.play_sfx("menu_signout")
		S.play_track(0, 0)
		S.play_track(1, 1)
		S.play_track(2, 0)
	elif signup_now.type == C.DEVICES.TOUCHSCREEN:
		signup_modal.start_setup_touch(
			signup_now.player_number
		)
		S.play_sfx("menu_signout")
		S.play_track(0, 0)
		S.play_track(1, 1)
		S.play_track(2, 0)
		$TouchButton.hide()
	else:
		# online
		# censor name
		var matched = R.censor_regex.search(signup_now.name)
		if null != matched:
			signup_now.censored = true
			signup_now.name = R.grawlix(len(signup_now.name))
		if R.get_settings_value("room_openness") == 2:
			signup_ended(
				signup_now.name, 0
			)
		elif R.get_settings_value("room_openness") == 1:
			signup_modal.start_setup_remote(
				signup_now.name
			)
			S.play_sfx("menu_signout")
			S.play_track(0, 0)
			S.play_track(1, 1)
			S.play_track(2, 0)
		else:
			printerr("Why are you here? Room is not open")

func signup_ended(name, keyboard_type):
	# check if player is remote and got rejected
	if keyboard_type == -1:
		S.play_sfx("menu_fail")
		Fb.reject_remote_player(signup_now.remote_device_name)
		used_ids.erase(signup_now.remote_device_name) # allow rejoin
	# end check
	else:
		var box = signup_box.instance()
		S.play_sfx("menu_signin")
		$Players.add_child(box)
		var icon_name = ""
		var name_type = 0
		var default_name = ""
		# find icon to use
		if signup_now.type == C.DEVICES.GAMEPAD:
			match signup_now.side:
				0:
					default_name = "Геймпад %d" % (signup_now.device_number + 1)
					icon_name = "gp"
				1:
					default_name = "Shared L %d" % (signup_now.device_number + 1)
					icon_name = "gp_left"
				2:
					default_name = "Shared R %d" % (signup_now.device_number + 1)
					icon_name = "gp_right"
		elif signup_now.type == C.DEVICES.KEYBOARD:
			icon_name = "kb"
			keyboard_type = 0
			match signup_now.input_slot_number:
				0:
					default_name = "Клав. ЦФЫВ"
				1:
					default_name = "Клав. ПМИТ"
				2:
					default_name = "Клав. ШОЛД"
				3:
					default_name = "Нумпад"
		elif signup_now.type == C.DEVICES.TOUCHSCREEN:
			icon_name = "touch"
			keyboard_type = 0
			default_name = "Курсор Рука"
		elif signup_now.type == C.DEVICES.REMOTE:
			icon_name = "online"
			keyboard_type = 3
			var device_number = C.add_controller(C.DEVICES.REMOTE, signup_now.remote_device_name)
			signup_now.device_number = device_number
			default_name = "Теле-Пульт %d" % (len(R.players) + 1)
		else:
			icon_name = "retro"
			default_name = "Игрок %d" % (len(R.players) + 1)
		# has name been censored before this point?
		if signup_now.censored == true:
			name_type = 2
		# is name default?
		elif name == "":
			name = default_name
			name_type = 1
		# is name "fuck you"?
		else:
			var matched = R.censor_regex.search(name)
			if null != matched:
				name_type = 2
				name = R.grawlix(len(name))
		box.setup(name, len(R.players), icon_name)
		var player_device_index = signup_now.device_number # [input revamp]
		if signup_now.type == C.DEVICES.GAMEPAD:
			player_device_index = signup_now.input_slot_number
		elif signup_now.type == C.DEVICES.REMOTE:
			player_device_index = C.lookup_button(C.DEVICES.REMOTE, signup_now.remote_device_name, 0).player;
			keyboard_type = 3
		var player = {
			name = name,
			name_type = name_type,
			score = 0,
			accuracy = [0, 0],
			device = signup_now.type,
			device_index = player_device_index,
			device_name = signup_now.remote_device_name if signup_now.type == C.DEVICES.REMOTE else "N/A",
			has_lifesaver = true,
			player_number = len(R.players),
			side = signup_now.side,
			keyboard = keyboard_type
		}
		print("Appending new player: ", player)
		if len(R.players) == 0:
			if R.get_settings_value("remote_start"):
				$Ready/Label2.set_text("или нажмите «Return» на клавиатуре")
			if signup_now.type == C.DEVICES.GAMEPAD:
				$Ready/Label.set_text("Нажмите «㍝», чтобы начать!")
			elif signup_now.type == C.DEVICES.KEYBOARD or (
				signup_now.type == C.DEVICES.REMOTE and !R.get_settings_value("remote_start")
			):
				$Ready/Label.set_text("Нажмите «Return», чтобы начать!")
				$Ready/Label2.set_text("")
			elif signup_now.type == C.DEVICES.TOUCHSCREEN:
				$Ready/Label.set_text("Нажмите здесь, чтобы начать!")
			elif signup_now.type == C.DEVICES.REMOTE:
				$Ready/Label.set_text("Нажмите «Начать», чтобы начать!")
			$Ready/Anim.play("Enter")
		R.players.append(player)
		if len(R.players) >= 1 + R.get_settings_value("room_size"):
			# Full room indicator.
			$Ready2/Anim.play("Enter")


		if signup_now.type == C.DEVICES.REMOTE:
			give_player_nick(player.device_name)
		else:
			Fb.update_player_count(len(R.players))
	S.play_track(0, 0.0 if len(R.players) else 1.0)
	S.play_track(1, 0.0)
	S.play_track(2, 1.0 if len(R.players) else 0.0)
	yield(get_tree().create_timer(1.0), "timeout")
	signup_now = {}

func start_game():
	# disconnect this signal before exiting the RIGHT way
#	self.disconnect("tree_exited", Ws, "close_room")
	print("Start the game!")
	$MouseMask.show()
	R.uuid_reset()
	# pass on the duty of registering new audience members to Root while the game is on
	R.listen_for_new_remote_join()
	menu_root.start_game()

func _on_TouchButton_pressed():
	# touchscreen player is in slot 4
	if 4 in used_ids:
		return
	used_ids.append(4)
	signup_queue.append(
		{
			"type": C.DEVICES.TOUCHSCREEN,
			"device_number": 4,
			"input_slot_number": 4,
			"player_number": p_count,
			"side": 0,
			"censored": false,
		}
	)
	p_count += 1
	check_full()

func _on_Ready_gui_input(event):
	if R.players.empty(): return
	if R.players[0].device == C.DEVICES.TOUCHSCREEN:
		if event is InputEventMouseButton and event.pressed and event.button_index == 1:
			start_game()

# if the remote controller finishes signup before the html can load, their nickname will be "signing up..."
func give_player_nick(id):
	for p in R.players:
		if p.device == C.DEVICES.REMOTE and p.device_name == id:
			Fb.add_remote_player(
				id, p.name, p.player_number
			)
			return
	# If we can't find the browser in the player list,
	# Check if it's an audience member.
#	Fb.add_remote_audience(id, "p.namewhat the fuck")

func update_loading_progress(partial: int, total: int, eta: int):
	$LoadingIndicator.update_loading_progress(partial, total, eta)
