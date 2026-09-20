extends Control

# Night Shift: After Hours - an original FNAF-inspired survival prototype.
const NIGHT_LENGTH := 90.0
const ROOMS := ["1A Stage", "1B Dining", "5 Backstage", "2A West Hall", "3 Supply", "4A East Hall", "Pirate Cove", "Office"]
const CALLS := {
  1: "Day Guard: Ha! Another night cleaning up my mess. Bonnie is set to AI 5/50 tonight. Try not to break anything.",
  2: "Day Guard: Welcome back, cleaner. Foxy is awake now. Keep the office door open and flash him when he runs.",
  3: "Day Guard: Chica joined the party. She may jam your cameras from Parts & Service. Flash her before that happens.",
  4: "Day Guard: AI is higher tonight. My shift was a disaster, so your cleanup is worse. Good luck!",
  5: "Day Guard: Freddy is moving now. He laughs five times on the way in. Flash him at the door before he gets you.",
  6: "Day Guard: One last shift... I will miss teasing you. Afton is here. All of them reset at 3 AM, then the real fight begins."
}

var screen: String = "menu"
var night := 1
var elapsed := 0.0
var power := 100.0
var insanity := 0.0
var dirt := 0
var camera_up := false
var camera := 0
var left_closed := false
var right_closed := false
var flashlight_ready := true
var game_over := false
var night_won := false
var n_hold := 0.0
var phone_shown := false
var phone_text := ""
var tip := "Tip: Clean the office early."
var anims: Array[Dictionary] = []
var jumpscare_name := ""
var jumpscare_message := ""
var labels: Dictionary = {}

func _ready() -> void:
  _show_menu()

func make_label(parent: Node, text: String, pos: Vector2, size: Vector2, font := 20) -> Label:
  var l := Label.new()
  l.text = text
  l.position = pos
  l.size = size
  l.add_theme_font_size_override("font_size", font)
  l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
  parent.add_child(l)
  return l

func clear_screen() -> void:
  for child in get_children(): child.queue_free()
  labels.clear()

func panel(parent: Node, pos: Vector2, size: Vector2, color: Color) -> ColorRect:
  var p := ColorRect.new()
  p.position = pos; p.size = size; p.color = color; parent.add_child(p)
  return p

func _show_menu() -> void:
  screen = "menu"; clear_screen();
  panel(self, Vector2.ZERO, Vector2(1280,720), Color("08090f"))
  make_label(self, "NIGHT SHIFT", Vector2(0,105), Vector2(1280,75), 58).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  make_label(self, "AFTER HOURS", Vector2(0,178), Vector2(1280,55), 34).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  make_label(self, "HELP WANTED AT NIGHT SHIFT: AFTER HOURS", Vector2(0,290), Vector2(1280,40), 25).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  make_label(self, "A night guard is needed to watch the cameras, doors, and a very messy office.", Vector2(0,345), Vector2(1280,35), 18).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  make_label(self, "Hold N to skip this notice", Vector2(940,670), Vector2(300,30), 18).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
  make_label(self, "Press 1-6 to choose a night", Vector2(0,600), Vector2(1280,35), 22).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  labels["menu_progress"] = make_label(self, "", Vector2(0,550), Vector2(1280,30), 18)

func _start_night(which: int) -> void:
  night = clampi(which, 1, 6); elapsed = 0; power = 100; insanity = 0; camera_up = false; camera = 0
  left_closed = false; right_closed = false; flashlight_ready = true; game_over = false; night_won = false
  dirt = night * 2; phone_shown = false; screen = "game"
  anims = []
  _add_anim("Bonnie", "left", 5 if night == 1 else (10 if night == 2 else (15 if night == 3 else (25 if night >= 4 else 5))))
  if night >= 3: _add_anim("Chica", "right", 15 if night == 3 else (25 if night >= 4 else 15))
  if night >= 5: _add_anim("Freddy", "right", 25)
  if night >= 2: _add_anim("Foxy", "left", 12)
  if night >= 6: _add_anim("Afton", "both", 50)
  _build_game()

func _add_anim(n: String, side: String, ai: int) -> void:
  anims.append({"name":n, "side":side, "ai":ai, "phase":0, "clock":randf_range(2.0,8.0), "laughs":0, "cooldown":0.0, "disabled":false})

func _build_game() -> void:
  clear_screen(); panel(self, Vector2.ZERO, Vector2(1280,720), Color("101116"))
  labels["time"] = make_label(self,"12 AM",Vector2(535,16),Vector2(210,45),32); labels["time"].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  labels["power"] = make_label(self,"POWER 100%",Vector2(1020,20),Vector2(230,35),22)
  labels["tip"] = make_label(self,tip,Vector2(850,65),Vector2(380,52),17)
  labels["insanity"] = make_label(self,"INSANITY 0%",Vector2(25,20),Vector2(240,35),22)
  labels["dirt"] = make_label(self,"Office mess: %d/12" % dirt,Vector2(25,58),Vector2(260,35),18)
  labels["office"] = make_label(self,"OFFICE\n\nDesk: flashlight ready\nSnack trays: [1] closed  [2] open  [3] closed  [4] open",Vector2(160,140),Vector2(960,390),30)
  labels["status"] = make_label(self,"Night %d started. Clean the office with F." % night,Vector2(150,625),Vector2(980,45),20); labels["status"].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  labels["phone"] = make_label(self,"",Vector2(30,470),Vector2(360,125),17)
  labels["doors"] = make_label(self,"[A] LEFT: OPEN                 [D] RIGHT: OPEN",Vector2(250,575),Vector2(780,35),22); labels["doors"].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  labels["camera"] = make_label(self,"",Vector2(720,120),Vector2(510,360),22)
  _update_ui()

func _process(delta: float) -> void:
  if screen == "menu":
    if Input.is_key_pressed(KEY_N):
      n_hold += delta; labels.get("menu_progress", Label.new()).text = "Skipping notice: %d%%" % int(min(100.0,n_hold * 100.0 / 1.2))
      if n_hold >= 1.2: _start_night(1)
    else: n_hold = 0
    return
  if screen != "game" or game_over or night_won: return
  elapsed += delta; insanity = max(0.0, insanity - delta * 0.75)
  _phone_call(); _update_anims(delta); _update_power(delta); _update_ui()
  if elapsed >= NIGHT_LENGTH + (15.0 if night == 6 else 0.0): _win_night()

func _phone_call() -> void:
  if not phone_shown and elapsed >= 3.0:
    phone_shown = true; phone_text = CALLS[night]; labels["phone"].text = "PHONE CALL\n" + phone_text

func _phone_call() -> void:
  if not phone_shown and elapsed >= 3.0:
    phone_shown = true; phone_text = CALLS[night]; labels["phone"].text = "PHONE CALL\n" + phone_text

func _update_power(delta: float) -> void:
  var drain := 0.45 + (0.35 if camera_up else 0.0) + (0.3 if left_closed else 0.0) + (0.3 if right_closed else 0.0)
  power = max(0.0, power - drain * delta)
  if power <= 0: _lose("The power died. Something is breathing in the dark.")

func _update_anims(delta: float) -> void:
  for a in anims:
    if a["disabled"]: continue
    a["cooldown"] = max(0.0, float(a["cooldown"]) - delta); a["clock"] -= delta
    if a["clock"] > 0: continue
    var chance := (float(a["ai"]) / 50.0) * (0.35 + elapsed / NIGHT_LENGTH)
    a["clock"] = max(1.5, 9.0 - float(a["ai"]) / 8.0)
    if randf() > chance: continue
    a["phase"] += 1
    if a["name"] == "Freddy": a["laughs"] += 1; tip = "Tip: Freddy has laughed %d/5 times." % a["laughs"]
    if a["name"] == "Afton" and a["phase"] >= 2: a["phase"] = 2
    if a["phase"] >= 4:
      var side: String = a["side"]
      if a["name"] == "Foxy" or a["name"] == "Afton": side = "left" if randf() < 0.5 else "right"
      if a["name"] == "Foxy" or a["name"] == "Afton": _run_attack(a, side)
      elif (side == "left" and not left_closed) or (side == "right" and not right_closed): _lose(a["name"] + " reached the open door.")
      else: a["phase"] = 2; labels["status"].text = a["name"] + " is waiting at the closed door."
    if a["name"] == "Chica" and a["phase"] == 2: tip = "Tip: Chica may disable cameras in Parts & Service. Flash her."
  if night == 6 and elapsed > 45 and elapsed < 48:
    for a in anims: a["phase"] = 0
    labels["status"].text = "3 AM: every animatronic returned to the stage. Afton is coming."

func _run_attack(a: Dictionary, side: String) -> void:
  if side == "left" and left_closed: _lose(a["name"] + " drained the power against the left door.")
  elif side == "right" and right_closed: _lose(a["name"] + " drained the power against the right door.")
  else: _lose(a["name"] + " is in the office. Flash sooner next time.")

func _update_ui() -> void:
  if not labels.has("time"): return
  var hour := mini(6, int(elapsed / 15.0)); var clock := ["12 AM","1 AM","2 AM","3 AM","4 AM","5 AM","6 AM"][hour]
  labels["time"].text = clock; labels["power"].text = "POWER %d%%" % int(power); labels["insanity"].text = "INSANITY %d%%" % int(insanity); labels["dirt"].text = "Office mess: %d/12" % dirt
  labels["doors"].text = "[A] LEFT: %s                 [D] RIGHT: %s" % ["CLOSED" if left_closed else "OPEN", "CLOSED" if right_closed else "OPEN"]
  labels["office"].text = "OFFICE\n\nDesk: flashlight %s\nSnack trays: [1] closed  [2] open  [3] closed  [4] open" % ("ready" if flashlight_ready else "recharging")
  if camera_up:
    var visible := []
    for a in anims:
      if a["phase"] == camera or (a["name"] == "Foxy" and camera == 6): visible.append("%s: phase %d" % [a["name"], a["phase"]])
    labels["camera"].text = "CAMERA MONITOR\nCAM %s\n%s\n\n[Q/E] change cam  [SPACE] flash" % [ROOMS[camera], "\n".join(visible) if visible.size() > 0 else "No movement detected."]
  else: labels["camera"].text = ""

func _unhandled_input(event: InputEvent) -> void:
  if event is not InputEventKey or not event.pressed or event.echo: return
  if screen == "menu":
    if event.keycode >= KEY_1 and event.keycode <= KEY_6: _start_night(event.keycode - KEY_0)
    return
  if screen != "game":
    if event.keycode == KEY_R: _show_menu()
    return
  if game_over or night_won: return
  match event.keycode:
    KEY_A: left_closed = not left_closed
    KEY_D: right_closed = not right_closed
    KEY_C: camera_up = not camera_up
    KEY_Q: camera = wrapi(camera - 1, 0, ROOMS.size())
    KEY_E: camera = wrapi(camera + 1, 0, ROOMS.size())
    KEY_F: dirt = maxi(0, dirt - 1); labels["status"].text = "You scrubbed the office."
    KEY_1: _eat_snack(false)
    KEY_2: _eat_snack(true)
    KEY_3: _eat_snack(false)
    KEY_4: _eat_snack(true)
    KEY_SPACE: _flash()
  _update_ui()

func _eat_snack(opened: bool) -> void:
  insanity = clampf(insanity + (10.0 if opened else -10.0), 0.0, 100.0)
  labels["status"].text = "You ate an %s snack. Insanity changed." % ("open" if opened else "unopened")

func _flash() -> void:
  flashlight_ready = false
  for a in anims:
    if a["name"] == "Foxy" or a["name"] == "Freddy" or a["name"] == "Afton" or (a["name"] == "Chica" and camera == 2):
      if a["phase"] >= 2: a["phase"] = 0; a["cooldown"] = 25.0 if a["name"] == "Freddy" else 3.0
  labels["status"].text = "FLASH! Movement reset."
  await get_tree().create_timer(0.7).timeout
  flashlight_ready = true

func _win_night() -> void:
  night_won = true; clear_screen(); panel(self,Vector2.ZERO,Vector2(1280,720),Color("07140b"))
  make_label(self,"6 AM",Vector2(0,150),Vector2(1280,75),64).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  make_label(self,"Night %d complete" % night,Vector2(0,250),Vector2(1280,45),30).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  if night == 6: make_label(self,"The children dragged Afton into the spring-lock darkness.\nYour check: $2,228",Vector2(0,340),Vector2(1280,90),27).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  make_label(self,"Press R for the main menu",Vector2(0,570),Vector2(1280,40),22).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _lose(reason: String) -> void:
  if game_over: return
  game_over = true; jumpscare_name = reason.split(" ")[0]; jumpscare_message = reason; clear_screen(); panel(self,Vector2.ZERO,Vector2(1280,720),Color("260408"))
  make_label(self,"!!! JUMPSCARE !!!",Vector2(0,100),Vector2(1280,80),58).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  make_label(self,jumpscare_name.to_upper(),Vector2(0,230),Vector2(1280,100),72).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  make_label(self,reason + "\n\n\"You should have listened...\"",Vector2(210,380),Vector2(860,110),28).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  make_label(self,"Press R for the main menu",Vector2(0,600),Vector2(1280,40),22).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
