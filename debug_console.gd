extends Control

@onready var line_edit := $VBoxContainer/LineEdit
@onready var logs := $VBoxContainer/ScrollContainer/logs
@onready var scroll := $VBoxContainer/ScrollContainer

var show_stats := false

var history: Array
var index := 0
var cheats
var dict: Dictionary

@onready var G := Global
@onready var timers := Timers

var r_paths:=RegEx.new()

func _init():
	history = []
	dict = {}
	r_paths.compile("\\$'([^']+)'")

func _ready():
	var cheat_file = 'res://scripts/cheats.gd'
	if ResourceLoader.exists(cheat_file):
		var script = load(cheat_file)
		cheats = script.new()
		add_child(cheats)

func _input(event: InputEvent):
	if !visible:
		return
	if event is InputEventKey and event.is_pressed():
		if event.keycode == KEY_UP:
			view_history(-1)
		elif event.keycode == KEY_DOWN:
			view_history(+1)

func _notification(what):
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		set_process_input(is_visible_in_tree())
		if is_visible_in_tree():
			line_edit.call_deferred('grab_focus')
			line_edit.text = ''

func _on_text_entered(new_text: String):
	if cheats and cheats.has_method(new_text):
		cheats.call(new_text)
		echo('code enabled')
		line_edit.text = ''
		return
	history.append(new_text)
	index = history.size()
	line_edit.text = ''

	var replaced := new_text
	for m in r_paths.search_all(new_text):
		var m1:String = m.get_string()
		var wp := WorldPath.new(m.get_string(1))
		var m2:String = 'Global.get_node("%s")' % wp.node_path
		replaced = replaced.replace(m1, m2)
	new_text = replaced

	var ex = Expression.new()
	var res = ex.parse(new_text, ['Global', 'RenderingServer', 'NavigationServer3D'])
	if res != OK:
		echo(ex.get_error_text())
		return
	var output = ex.execute([Global, RenderingServer, NavigationServer3D], self)
	if ex.has_execute_failed():
		echo(ex.get_error_text() + str(output))
	elif output != null:
		echo(str(output))
	scroll.scroll_to_end()

func help():
	echo('sorry, not implemented.')

func move(dir:Vector3):
	Global.get_player().global_translate(dir)

func debug_time(debugging := true, parent:Node = null):
	if !parent:
		parent = Global.get_player()
	parent.time_scale_response = debugging
	for c in parent.get_children():
		debug_time(debugging, c)

func ui():
	return Global.get_player().ui

func step():
	ui().unpause()
	ui().call_deferred('call_deferred', 'pause')

func time():
	if TimeManagement.time_slowed:
		TimeManagement.resume()
	else:
		TimeManagement.slow_time()

func noclip():
	Global.get_player().toggle_noclip()

func scene():
	return get_tree().current_scene

func set_time(p_time):
	scene().set_time(p_time)

func clear():
	for l in logs.get_children():
		l.queue_free()

func rapid_start():
	Global.add_item('wep_wave_shot')
	Global.add_item('wep_grav_gun')
	Global.add_item('wep_time_gun')
	Global.add_item('wep_pistol')
	Global.add_item('hover_scooter')
	Global.add_item('lantern')
	Global.add_item('flag', 10)

func scoot():
	Global.add_item('hover_scooter')
	Global.add_item('hover_speed_up', 10)

func item(item_id:String, count:int = 1):
	Global.add_item(item_id, count)

func rapid_end():
	var end_stats := [
		# Basics
		'medium/activated', 'mum/introduction',
		# Complications
		'mum/time', 'jackie/medium/network',
		'mum/discussed/jackie',
		# Layers
		'mum/postwar', 'visited/sherad', 'mum/tsirdi',
	]
	for s in end_stats:
		Global.add_stat(s)
	var numbered_stats := {
		'mum/info': 8,
		'mum/timebomb': 5,
		'talked/mum': 2,
		'talked/yaqazi': {'a':true, 'b':true, 'c':true}
	}
	for s in numbered_stats:
		Global.set_stat(s, numbered_stats[s])
	# Git yer capacitor
	Global.add_item('capacitor')

func coat(count := 1):
	for _i in range(count):
		var new_coat = Coat.new().randomize(Coat.Rarity.Plain, Coat.Rarity.Sublime)
		Global.add_coat(new_coat)

func echo(text):
	var label := Label.new()
	# TODO: label.autowrap = true
	logs.add_child(label)
	label.text = str(text)

func view_history(offset):
	if history.size() == 0:
		index = 0
		return
	index += offset
	if index < 0:
		index = 0
	if index >= history.size():
		index = history.size()
		line_edit.text = ''
		return
	else:
		line_edit.text = history[index]

func tp(location):
	print_debug('Teleport ', location)
	var chunk_name := ''
	if location is int:
		chunk_name = 'chunk%03d' % location
	else:
		chunk_name = str(location)
	var scn = get_tree().current_scene
	if scn.has_node('chunks'):
		scn = scn.get_node('chunks')
	if scn.has_node(chunk_name):
		#scn.unload_all()
		var pos = scn.get_node(chunk_name).global_transform.origin
		var player = Global.get_player()
		var ray_start = pos + Vector3.UP*3400
		var ray_end = pos + Vector3.DOWN*1000
		var col = Util.intersect_ray(ray_start, ray_end)
		if col:
			pos = col.position
		var new_transform = player.global_transform
		new_transform.origin = pos
		player.teleport_to(new_transform)
	else:
		return 'No chunk: ' + chunk_name

func stats():
	var t := Tree.new()
	t.columns = 2
	var root := t.create_item()
	_stats_add(Global.game_state.stats, t, root)
	t.custom_minimum_size.y = 900
	logs.add_child(t)
	return true

func _stats_add(d:Dictionary, tree: Tree, t:TreeItem):
	for k in d:
		var v = d[k]
		var sub := tree.create_item(t)
		sub.set_text(0, k)
		if v is Dictionary:
			sub.set_text(1, '...')
			_stats_add(v, tree, sub)
		else:
			sub.set_text(1, str(v))
	t.collapsed = true

func save(save_id := ''):
	var path:String = ''
	if save_id != '':
		path = Global.custom_save_path_f % save_id
	echo('Saving to: '+ path)
	Global.save_checkpoint(Global.get_player().get_save_transform(), path)

func load_game(save_id := ''):
	var path:String = Global.auto_save_path
	if save_id != '':
		path = Global.custom_save_path_f % save_id
	echo('Loading from: '+ path)
	Global.load_sync(true, path)

func lg(save_id := ''):
	load_game(save_id)

func load_chunk(chunk_name: String):
	var scn := get_tree().current_scene
	var chunk := scn.get_node(chunk_name)
	scn.chunk_loader.queue_load(chunk, false)
	echo('Loading '+ chunk_name)

func activate_chunk(chunk_name: String):
	var scn := get_tree().current_scene
	var chunk := scn.get_node(chunk_name)
	scn.chunk_loader.activate(chunk)
	echo('Activating '+ chunk_name)

func map(list, f: String):
	var result := []
	for l in list:
		result.append(l.call(f))
	return result

func chunk_debug():
	if !get_tree().current_scene.has_node('debug'):
		echo('No debug UI')
		return
	var n = get_tree().current_scene.get_node('debug')
	n.visible = !n.visible

func reload_player():
	var p := Global.get_player()
	var c = p.state.current
	p.state = PlayerStateMachine.new()
	p.state.set_current(c)

func time_scale(s:float):
	Engine.time_scale = s

func toggle_time(enabled: bool):
	if enabled:
		TimeManagement.start_time()
	else:
		TimeManagement.stop_time()

func mum_note(tag:String):
	Global.add_note('Debug: '+tag, ['mum', 'medium_quest', tag])

func debug_mum():
	mum_note('debug_pick_event')
	mum_note('debug_pick_layer')
	mum_note('debug_pick_modifier')

func sleepy():
	Global.get_player().sleep = 0.6

func set_time_scale(s: float):
	Engine.time_scale = s
	return Engine.time_scale
