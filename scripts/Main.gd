extends Control

const NIGHT_LENGTH := 90.0
const ROOMS := ["Stage", "Dining", "Backstage", "West Hall", "Supply", "East Hall", "Pirate Cove", "Office"]
const PHONE_CALLS := {
	1: "Day Guard: Another night. Bonnie AI is 5/50. Clean up my mess and stay sharp.",
	2: "Day Guard: Foxy is moving now. Keep the office door open only when needed and flash him when he gets close.",
	3: "Day Guard: Chica is active. She can jam the cameras from Parts & Service. Flash her before she resets the system.",
	4: "Day Guard: We are getting sloppy. You still have to clean after me, and the office is dirtier every night.",
	5: "Day Guard: Freddy is laughing now. He laughs five times before he attacks. Flash him at the door.",
	6: "Day Guard: Last night. Afton is coming. At 3 AM the others reset, then the real danger wakes up."
}

var screen := "menu"
var night := 1
var elapsed := 0.0
var power := 100.0
var insanity := 0.0
var camera_up := false
var camera_index := 0
var left_door := false
var right_door := false
var phone_shown := false
var game_over := false
var won := false
var title_skip_hold := 0.0
var ui := {}
var anims: Array[Dictionary] = []
var office_rect: ColorRect
var left_door_rect: ColorRect
var right_door_rect: ColorRect

func _ready() -> void:
	_show_menu()

func _create_label(parent: Node, text: String, pos: Vector2, size: Vector2, font_size: int = 20) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.size = size
	label.add_theme_font_size_override("font_size", font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(label)
	return label

func _show_menu() -> void:
	screen = "menu"
	for child in get_children():
		child.queue_free()
	ui.clear()

	var bg := ColorRect.new(); bg.color = Color("08090f"); bg.set_anchors_preset(Control.PRESET_FULL_RECT); add_child(bg)
	_create_label(self, "NIGHT SHIFT", Vector2(0, 100), Vector2(1280, 80), 58)
	_create_label(self, "AFTER HOURS", Vector2(0, 175), Vector2(1280, 60), 34)
	_create_label(self, "HELP WANTED AT NIGHT SHIFT: AFTER HOURS", Vector2(0, 285), Vector2(1280, 34), 24)
	_create_label(self, "A night guard is needed to watch the cameras, doors, and a messier office every night.", Vector2(0, 340), Vector2(1280, 30), 18)
	var hold_label := _create_label(self, "Hold N to skip this notice", Vector2(930, 660), Vector2(300, 28), 18)
	hold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var nights_label := _create_label(self, "Press 1-6 to choose a night", Vector2(0, 600), Vector2(1280, 32), 22)
	nights_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui["hold_progress"] = _create_label(self, "", Vector2(0, 570), Vector2(1280, 25), 18)
	ui["hold_progress"].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _start_night(which: int) -> void:
	night = clampi(which, 1, 6)
	elapsed = 0.0
	power = 100.0
	insanity = 0.0
	camera_up = false
	camera_index = 0
	left_door = false
	right_door = false
	phone_shown = false
	game_over = false
	won = false
	screen = "game"
	anims = []
	_add_anim("Bonnie", "left", 5 if night == 1 else 10 if night == 2 else 15 if night == 3 else 25)
	if night >= 2:
		_add_anim("Foxy", "left", 12)
	if night >= 3:
		_add_anim("Chica", "right", 15 if night == 3 else 25)
	if night >= 5:
		_add_anim("Freddy", "right", 25)
	if night >= 6:
		_add_anim("Afton", "both", 50)
	_build_game_ui()

func _add_anim(name: String, side: String, ai: int) -> void:
	anims.append({
		"name": name,
		"side": side,
		"ai": ai,
		"phase": 0,
		"timer": randf_range(2.0, 7.5),
		"laughs": 0,
		"cooldown": 0.0
	})

func _build_game_ui() -> void:
	for child in get_children():
		child.queue_free()
	ui.clear()

	var bg := ColorRect.new(); bg.color = Color("11131a"); bg.set_anchors_preset(Control.PRESET_FULL_RECT); add_child(bg)
	var office := ColorRect.new(); office.color = Color("1d1d20"); office.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 0); office.position = Vector2(160, 100); office.size = Vector2(960, 520); add_child(office)
	office_rect = office
	var desk := ColorRect.new(); desk.color = Color("302a24"); desk.position = Vector2(480, 480); desk.size = Vector2(320, 130); add_child(desk)
	left_door_rect = ColorRect.new(); left_door_rect.color = Color("28282d"); left_door_rect.position = Vector2(175, 120); left_door_rect.size = Vector2(110, 480); add_child(left_door_rect)
	right_door_rect = ColorRect.new(); right_door_rect.color = Color("28282d"); right_door_rect.position = Vector2(995, 120); right_door_rect.size = Vector2(110, 480); add_child(right_door_rect)

	ui["clock"] = _create_label(self, "12 AM", Vector2(530, 20), Vector2(220, 40), 32)
	ui["power"] = _create_label(self, "Power: 100%", Vector2(980, 20), Vector2(220, 35), 22)
	ui["insanity"] = _create_label(self, "Insanity: 0%", Vector2(40, 20), Vector2(220, 35), 22)
	ui["door_status"] = _create_label(self, "Left: OPEN    Right: OPEN", Vector2(350, 580), Vector2(580, 40), 22)
	ui["camera"] = _create_label(self, "Camera: Stage", Vector2(720, 120), Vector2(500, 300), 20)
	ui["tip"] = _create_label(self, "Tip: Keep the office clean and watch the door.", Vector2(860, 60), Vector2(340, 40), 17)
	ui["phone"] = _create_label(self, "", Vector2(30, 470), Vector2(350, 150), 16)
	ui["status"] = _create_label(self, "Night 1 started. Press C to view cameras.", Vector2(160, 640), Vector2(960, 40), 20)
	_update_ui()

func _process(delta: float) -> void:
	if screen == "menu":
		if Input.is_key_pressed(KEY_N):
			title_skip_hold += delta
			if "hold_progress" in ui:
				ui["hold_progress"].text = "Skipping notice: %d%%" % int(min(100.0, (title_skip_hold / 1.2) * 100.0))
			if title_skip_hold >= 1.2:
				_start_night(1)
		else:
			title_skip_hold = 0.0
			if "hold_progress" in ui:
				ui["hold_progress"].text = ""
		return

	if screen != "game" or game_over or won:
		return

	elapsed += delta
	power = max(0.0, power - (0.45 + (0.35 if camera_up else 0.0) + (0.25 if left_door else 0.0) + (0.25 if right_door else 0.0)) * delta)
	insanity = max(0.0, insanity - delta * 0.7)
	if power <= 0:
		_lose("The power died. Something is breathing in the dark.")
		return

	if not phone_shown and elapsed >= 3.0:
		phone_shown = true
		ui["phone"].text = "PHONE CALL\n" + PHONE_CALLS[night]

	_update_anim_ai(delta)
	_update_ui()

	if elapsed >= NIGHT_LENGTH:
		_won_screen()

func _update_anim_ai(delta: float) -> void:
	for anim in anims:
		anim["timer"] -= delta
		if anim["timer"] > 0.0:
			continue
		var chance := (float(anim["ai"]) / 50.0) * (0.35 + elapsed / NIGHT_LENGTH)
		anim["timer"] = max(1.2, 8.5 - float(anim["ai"]) / 7.0)
		if randf() > chance:
			continue
		anim["phase"] += 1
		if anim["name"] == "Freddy":
			anim["laughs"] += 1
			ui["status"].text = "Freddy laughs %d/5. Keep the flashlight ready." % anim["laughs"]
		if anim["phase"] >= 4:
			if anim["name"] == "Foxy" or anim["name"] == "Afton":
				if left_door or right_door:
					_lose(anim["name"] + " hit the door. Flash the hallway sooner next time.")
					return
				_lose(anim["name"] + " is in the office.")
				return
			if anim["side"] == "left" and not left_door:
				_lose(anim["name"] + " reached the left side open door.")
				return
			if anim["side"] == "right" and not right_door:
				_lose(anim["name"] + " reached the right side open door.")
				return
			anim["phase"] = 2

func _update_ui() -> void:
	if "clock" in ui:
		var hour_index := int(min(6, elapsed / 15.0))
		var clock_names := ["12 AM", "1 AM", "2 AM", "3 AM", "4 AM", "5 AM", "6 AM"]
		ui["clock"].text = clock_names[hour_index]
	if "power" in ui:
		ui["power"].text = "Power: %d%%" % int(power)
	if "insanity" in ui:
		ui["insanity"].text = "Insanity: %d%%" % int(insanity)
	if "door_status" in ui:
		ui["door_status"].text = "Left: %s    Right: %s" % ["CLOSED" if left_door else "OPEN", "CLOSED" if right_door else "OPEN"]
	if left_door_rect:
		left_door_rect.color = Color("9fd1ff") if left_door else Color("28282d")
	if right_door_rect:
		right_door_rect.color = Color("9fd1ff") if right_door else Color("28282d")
	if "camera" in ui:
		if camera_up:
			var file_text := "Camera: %s" % ROOMS[camera_index]
			var movement_text := "No movement detected."
			for anim in anims:
				if anim["phase"] > 0:
					movement_text = "%s: phase %d" % [anim["name"], anim["phase"]]
					break
			ui["camera"].text = "%s\n%s\n\n[Q/E] Change camera  [SPACE] Flash" % [file_text, movement_text]
		else:
			ui["camera"].text = "Camera: Off"

func _unhandled_input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.echo:
		return

	if screen == "menu":
		if event.keycode >= KEY_1 and event.keycode <= KEY_6:
			_start_night(int(event.keycode - KEY_0))
		return
	if screen != "game" or game_over or won:
		if event.keycode == KEY_R:
			_show_menu()
		return
	match event.keycode:
		KEY_A:
			left_door = not left_door
			ui["status"].text = "Left door %s" % ("closed" if left_door else "opened")
		KEY_D:
			right_door = not right_door
			ui["status"].text = "Right door %s" % ("closed" if right_door else "opened")
		KEY_C:
			camera_up = not camera_up
			ui["status"].text = "Camera monitor %s" % ("on" if camera_up else "off")
		KEY_Q:
			camera_index = wrapi(camera_index - 1, 0, ROOMS.size())
		KEY_E:
			camera_index = wrapi(camera_index + 1, 0, ROOMS.size())
		KEY_SPACE:
			_flash()
		KEY_F:
			insanity = max(0.0, insanity - 5.0)
			ui["status"].text = "The office is cleaner."
		KEY_1, KEY_2, KEY_3, KEY_4:
			_eat_snack(event.keycode == KEY_2 or event.keycode == KEY_4)
	_update_ui()

func _eat_snack(opened: bool) -> void:
	if opened:
		insanity = min(100.0, insanity + 10.0)
		ui["status"].text = "You ate an open snack. Insanity +10%."
	else:
		insanity = max(0.0, insanity - 10.0)
		ui["status"].text = "You ate a sealed snack. Insanity -10%."

func _flash() -> void:
	for anim in anims:
		if anim["name"] == "Foxy" and anim["phase"] > 0:
			anim["phase"] = 0
			anim["timer"] = 8.0
		if anim["name"] == "Freddy" and anim["phase"] > 0:
			anim["phase"] = 0
			anim["timer"] = 9.0
		if anim["name"] == "Chica" and anim["phase"] > 0:
			anim["phase"] = 0
			anim["timer"] = 8.0
	ui["status"].text = "Flash used. Some movement reset."

func _won_screen() -> void:
	won = true
	for child in get_children():
		child.queue_free()
	var bg := ColorRect.new(); bg.color = Color("07140b"); bg.set_anchors_preset(Control.PRESET_FULL_RECT); add_child(bg)
	_create_label(self, "6 AM", Vector2(0, 140), Vector2(1280, 80), 60)
	_create_label(self, "Night %d complete" % night, Vector2(0, 240), Vector2(1280, 40), 28)
	_create_label(self, "Your check: $2,228\nPress R to return to the main menu", Vector2(0, 340), Vector2(1280, 100), 26)

func _lose(reason: String) -> void:
	if game_over:
		return
	game_over = true
	for child in get_children():
		child.queue_free()
	var bg := ColorRect.new(); bg.color = Color("2a0708"); bg.set_anchors_preset(Control.PRESET_FULL_RECT); add_child(bg)
	_create_label(self, "!!! JUMPSCARE !!!", Vector2(0, 110), Vector2(1280, 80), 60)
	_create_label(self, reason, Vector2(0, 240), Vector2(1280, 110), 26)
	_create_label(self, "Press R to return to the main menu", Vector2(0, 600), Vector2(1280, 40), 24)
