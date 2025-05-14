class_name DebugConsole
extends Control

@onready var line_edit := $VBoxContainer/LineEdit
@onready var logs := $VBoxContainer/ScrollContainer/logs
@onready var scroll := $VBoxContainer/ScrollContainer

var show_stats := false

var history: Array
var index := 0
var cheats
var dict: Dictionary
# Meant to be overridden to add parse-time variables
var variables: Dictionary

func _init():
	history = []
	dict = {}

func _ready():
	var cheat_file = 'res://scripts/cheats.gd'
	if ResourceLoader.exists(cheat_file):
		var script = load(cheat_file)
		cheats = script.new()
		add_child(cheats)
	line_edit.text_submitted.connect(_on_text_submitted)

func _input(event: InputEvent):
	if !visible:
		return
	if event is InputEventKey and event.is_pressed():
		if event.keycode == KEY_UP:
			view_history(-1)
		elif event.keycode == KEY_DOWN:
			view_history(+1)

func _notification(what):
	if what == NOTIFICATION_VISIBILITY_CHANGED and line_edit:
		set_process_input(is_visible_in_tree())
		if is_visible_in_tree():
			line_edit.grab_focus.call_deferred()
			line_edit.text = ''

func _on_text_submitted(new_text: String):
	if cheats and cheats.has_method(new_text):
		cheats.call(new_text)
		echo('code enabled')
		line_edit.text = ''
		return
	history.append(new_text)
	index = history.size()
	line_edit.text = ''

	var replaced := _special_parse(new_text)

	var ex := Expression.new()
	variables.sort()
	
	var res := ex.parse(new_text, variables.keys())
	if res != OK:
		echo(ex.get_error_text())
		return
	var output = ex.execute(variables.values(), self)
	if ex.has_execute_failed():
		echo(ex.get_error_text() + str(output))
	elif output != null:
		echo(str(output))
	scroll.scroll_vertical = scroll.get_v_scroll_bar().max_value

# Meant to be overridden
func _special_parse(s: String) -> String:
	return s

func help():
	echo('sorry, not implemented.')

func scene():
	return get_tree().current_scene

func set_time(p_time):
	scene().set_time(p_time)

func clear():
	for l in logs.get_children():
		l.queue_free()

func echo(text):
	var label := Label.new()
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

func time_scale(s:float):
	Engine.time_scale = s
