extends Control

const NIGHT_LENGTH := 90.0
const ROOMS := ["1A — SHOW STAGE", "1B — DINING AREA", "5 — BACKSTAGE", "2A — WEST HALL", "3 — SUPPLY CLOSET", "4A — EAST HALL", "1C — PIRATE COVE", "OFFICE"]
const PHONE_CALLS := {1:"Day Guard: Bonnie is only AI 5 tonight. Try not to make my mess worse.",2:"Day Guard: Foxy is awake. Watch Pirate Cove and flash him when he runs.",3:"Day Guard: Chica can jam cameras from Backstage. Flash her.",4:"Day Guard: Higher AI tonight. The office is even dirtier.",5:"Day Guard: Freddy laughs five times before attacking. Flash him at the door.",6:"Day Guard: Afton is here. At 3 AM the others reset. I will miss you."}

var screen := "menu"
var night := 1
var elapsed := 0.0
var power := 100.0
var insanity := 100.0
var camera_up := false
var camera_index := 0
var left_door := false
var right_door := false
var phone_shown := false
var game_over := false
var won := false
var title_hold := 0.0
var ui := {}
var anims: Array[Dictionary] = []
var camera_frame: ColorRect
var camera_static: TextureRect
var left_door_rect: ColorRect
var right_door_rect: ColorRect

func _ready() -> void:
	_show_menu()

func _label(text: String, pos: Vector2, size: Vector2, font := 20) -> Label:
	var l := Label.new(); l.text = text; l.position = pos; l.size = size
	l.add_theme_font_size_override("font_size", font); l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; add_child(l); return l

func _clear() -> void:
	for child in get_children(): child.queue_free()
	ui.clear(); camera_frame = null; camera_static = null; left_door_rect = null; right_door_rect = null

func _show_menu() -> void:
	screen = "menu"; _clear(); var bg := ColorRect.new(); bg.color = Color("08090f"); bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(bg)
	_label("NIGHT SHIFT\nAFTER HOURS", Vector2(0,105), Vector2(1280,130), 56)
	_label("HELP WANTED AT NIGHT SHIFT: AFTER HOURS", Vector2(0,285), Vector2(1280,35), 24)
	_label("Hold N to skip this notice", Vector2(900,660), Vector2(350,30), 18)
	_label("Press 1–6 to choose a night", Vector2(0,600), Vector2(1280,35), 22)
	ui["hold"] = _label("", Vector2(0,565), Vector2(1280,28), 18)

func _start_night(which: int) -> void:
	night = clampi(which,1,6); elapsed = 0.0; power = 100.0; insanity = 100.0; camera_up = false; camera_index = 0; left_door = false; right_door = false; phone_shown = false; game_over = false; won = false; screen = "game"; anims = []
	_add_anim("Bonnie", "left", 5 if night == 1 else 10 if night == 2 else 15 if night == 3 else 25)
	if night >= 2: _add_anim("Foxy", "left", 12)
	if night >= 3: _add_anim("Chica", "right", 15 if night == 3 else 25)
	if night >= 5: _add_anim("Freddy", "right", 25)
	if night >= 6: _add_anim("Afton", "both", 50)
	_build_game()

func _add_anim(name: String, side: String, ai: int) -> void:
	anims.append({"name":name,"side":side,"ai":ai,"phase":0,"timer":randf_range(2.0,7.0),"laughs":0})

func _build_game() -> void:
	_clear(); var bg := ColorRect.new(); bg.color = Color("0b0d12"); bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(bg)
	var office := ColorRect.new(); office.color = Color("1d1e22"); office.position = Vector2(150,105); office.size = Vector2(980,495); add_child(office)
	var desk := ColorRect.new(); desk.color = Color("302a24"); desk.position = Vector2(460,480); desk.size = Vector2(360,120); add_child(desk)
	left_door_rect = ColorRect.new(); left_door_rect.position = Vector2(165,120); left_door_rect.size = Vector2(105,460); add_child(left_door_rect)
	right_door_rect = ColorRect.new(); right_door_rect.position = Vector2(1010,120); right_door_rect.size = Vector2(105,460); add_child(right_door_rect)
	ui["clock"] = _label("12 AM",Vector2(535,15),Vector2(210,42),32); ui["power"] = _label("POWER 100%",Vector2(1020,20),Vector2(220,32),21); ui["insanity"] = _label("INSANITY 100%",Vector2(25,20),Vector2(250,32),21)
	ui["doors"] = _label("[A] LEFT: OPEN        [D] RIGHT: OPEN",Vector2(310,575),Vector2(660,35),21); ui["status"] = _label("Night %d started. Press C for cameras." % night,Vector2(150,635),Vector2(980,35),19); ui["phone"] = _label("",Vector2(20,450),Vector2(360,145),16); ui["tip"] = _label("Tip: insanity reaching 0% is fatal.",Vector2(850,60),Vector2(380,40),16)
	_build_camera_ui(); _update_ui()

func _build_camera_ui() -> void:
	camera_frame = ColorRect.new(); camera_frame.position = Vector2(690,105); camera_frame.size = Vector2(540,405); camera_frame.color = Color("15191b"); camera_frame.visible = false; add_child(camera_frame)
	camera_static = TextureRect.new(); camera_static.texture = load("res://assets/camera_static.svg"); camera_static.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; camera_static.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED; camera_static.position = Vector2(10,45); camera_static.size = Vector2(320,220); camera_static.modulate = Color(1,1,1,0.22); camera_static.mouse_filter = Control.MOUSE_FILTER_IGNORE; camera_frame.add_child(camera_static)
	ui["cam_title"] = _label_in(camera_frame,"CAMERA MONITOR",Vector2(18,10),Vector2(500,30),22)
	ui["cam_room"] = _label_in(camera_frame,"",Vector2(18,275),Vector2(500,35),21)
	ui["cam_contents"] = _label_in(camera_frame,"",Vector2(18,310),Vector2(500,80),18)

func _label_in(parent: Node, text: String, pos: Vector2, size: Vector2, font := 20) -> Label:
	var l := Label.new(); l.text=text; l.position=pos; l.size=size; l.add_theme_font_size_override("font_size",font); l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; l.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; parent.add_child(l); return l

func _process(delta: float) -> void:
	if screen == "menu":
		if Input.is_key_pressed(KEY_N):
			title_hold += delta; ui["hold"].text = "Skipping notice: %d%%" % int(min(100.0,title_hold/1.2*100.0))
			if title_hold >= 1.2: _start_night(1)
		else: title_hold = 0.0; ui["hold"].text = ""
		return
	if screen != "game" or game_over or won: return
	elapsed += delta; power = max(0.0,power-(0.45+(0.35 if camera_up else 0.0)+(0.25 if left_door else 0.0)+(0.25 if right_door else 0.0))*delta); insanity = max(0.0,insanity-delta*(1.2 if camera_up else 0.7))
	if insanity <= 0.0: _lose("Your insanity reached 0%. The darkness took over."); return
	if power <= 0.0: _lose("The power died. Something is breathing in the dark."); return
	if not phone_shown and elapsed >= 3.0: phone_shown=true; ui["phone"].text="PHONE CALL\n"+PHONE_CALLS[night]
	_update_anim_ai(delta); _update_ui()
	if elapsed >= NIGHT_LENGTH: _won_screen()

func _update_anim_ai(delta: float) -> void:
	for a in anims:
		a["timer"] -= delta
		if a["timer"] > 0: continue
		a["timer"] = max(1.2,8.5-float(a["ai"])/7.0)
		if randf() > float(a["ai"])/50.0*(0.35+elapsed/NIGHT_LENGTH): continue
		a["phase"] += 1
		if a["name"] == "Freddy": a["laughs"] += 1; ui["status"].text="Freddy laughs %d/5. Flash him at the door." % a["laughs"]
		if a["phase"] >= 4:
			if a["name"] in ["Foxy","Afton"]: _lose(a["name"]+" reached the office. Flash sooner next time."); return
			if a["side"] == "left" and not left_door: _lose(a["name"]+" reached the open left door."); return
			if a["side"] == "right" and not right_door: _lose(a["name"]+" reached the open right door."); return
			a["phase"] = 2

func _update_ui() -> void:
	if not ui.has("clock"): return
	ui["clock"].text = ["12 AM","1 AM","2 AM","3 AM","4 AM","5 AM","6 AM"][mini(6,int(elapsed/15.0))]; ui["power"].text="POWER %d%%" % int(power); ui["insanity"].text="INSANITY %d%%" % int(insanity); ui["doors"].text="[A] LEFT: %s        [D] RIGHT: %s" % ["CLOSED" if left_door else "OPEN","CLOSED" if right_door else "OPEN"]
	left_door_rect.color=Color("9fd1ff") if left_door else Color("28282d"); right_door_rect.color=Color("9fd1ff") if right_door else Color("28282d")
	if camera_frame:
		camera_frame.visible=camera_up
		if camera_up:
			ui["cam_room"].text="CAM %d  —  %s" % [camera_index+1,ROOMS[camera_index]]
			var found=[]
			for a in anims:
				if (a["phase"] == camera_index) or (a["name"] == "Foxy" and camera_index == 6): found.append("%s detected — movement phase %d" % [a["name"],a["phase"]])
			ui["cam_contents"].text="\n".join(found) if found.size()>0 else "No movement detected.\n[Q] previous   [E] next   [SPACE] flash"

func _unhandled_input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.echo: return
	if screen == "menu":
		if event.keycode >= KEY_1 and event.keycode <= KEY_6: _start_night(event.keycode-KEY_0)
		return
	if screen != "game" or game_over or won:
		if event.keycode == KEY_R: _show_menu()
		return
	match event.keycode:
		KEY_A: left_door=!left_door
		KEY_D: right_door=!right_door
		KEY_C: camera_up=!camera_up
		KEY_Q: camera_index=wrapi(camera_index-1,0,ROOMS.size())
		KEY_E: camera_index=wrapi(camera_index+1,0,ROOMS.size())
		KEY_SPACE: _flash()
		KEY_F: insanity=min(100.0,insanity+2.0); ui["status"].text="The office is cleaner."
		KEY_1,KEY_2,KEY_3,KEY_4: insanity=min(100.0,insanity+10.0); ui["status"].text="Snack eaten. Insanity restored 10%."
	_update_ui()

func _flash() -> void:
	for a in anims:
		if a["name"] in ["Foxy","Freddy","Chica","Afton"] and a["phase"]>0: a["phase"]=0; a["timer"]=8.0
	ui["status"].text="FLASH! Movement reset."

func _won_screen() -> void:
	won=true; _clear(); var bg:=ColorRect.new(); bg.color=Color("07140b"); bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(bg); _label("6 AM",Vector2(0,140),Vector2(1280,80),60); _label("Night %d complete" % night,Vector2(0,240),Vector2(1280,40),28); _label("You beat all six nights!\nYour check: $2,228" if night==6 else "Night %d complete.\nNo check yet — beat Night 6 to get paid." % night,Vector2(0,340),Vector2(1280,100),26); _label("Press R to return to the main menu",Vector2(0,600),Vector2(1280,40),24)

func _lose(reason: String) -> void:
	if game_over: return
	game_over=true; _clear(); var bg:=ColorRect.new(); bg.color=Color("2a0708"); bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(bg); _label("!!! JUMPSCARE !!!",Vector2(0,110),Vector2(1280,80),60); _label(reason,Vector2(0,240),Vector2(1280,110),26); _label("Press R to return to the main menu",Vector2(0,600),Vector2(1280,40),24)
