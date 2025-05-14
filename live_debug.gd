extends CanvasLayer

# Dictionary on the type name
# to an array of free objects
var pool: Dictionary
var col_request := Vector2.ZERO

class LabelListener extends Node:
	var source: Object
	var property: String
	var label: Label
	var arguments = null
	func _enter_tree():
		label = get_parent() as Label

	func _process(_delta: float):
		if !is_instance_valid(source):
			label.text = '<Freed>'
			return
		var sn : String
		if source is Node:
			sn = source.name
		else:
			sn = str(source)
		var prop: String
		var val: String
		if arguments is Array:
			prop = '%s::%s' % [property, arguments]
			val = str(source.callv(property, arguments))
		else:
			prop = property
			val = str(source.get(property))
		label.text = '%s[%s]: %s' % [sn, prop, val]

class Box:
	var panel: Control
	var box: VBoxContainer
	func _init(p_p: Control):
		panel = p_p
		box = LiveDebug.dry('VBoxContainer')
		if !box:
			box = VBoxContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.size_flags_vertical = Control.SIZE_EXPAND_FILL
		panel.add_child(box)
	
	static func default_label() -> Label:
		var l := Label.new()
		l.size_flags_horizontal = Label.SIZE_EXPAND_FILL
		l.size_flags_vertical = Label.SIZE_FILL
		#l.align = Label.ALIGN_LEFT
		return l
	
	static func default_button() -> Button:
		return Button.new()
	
	func add_label(text: String) -> Label:
		var l := LiveDebug.dry('Label') as Label
		if !l:
			l = Box.default_label()
		l.text = text
		box.add_child(l)
		return l
	
	func add_button(label: String, object: Object, method: String, binds = [], flags = 0) -> Button:
		var b := LiveDebug.dry('Button') as Button
		if !b:
			b = Box.default_button()
		b.text = label
		for s in b.get_signal_list():
			for c in b.get_signal_connection_list(s.name):
				c.signal.disconnect(c.callable)
		b.connect("pressed", Callable(object, method).bindv(binds), flags)
		box.add_child(b)
		return b
	
	func property(source: Object, prop: String, args = null) -> Label:
		var l := LiveDebug.dry('Label') as Label
		if !l:
			l = Box.default_label()
		box.add_child(l)
		l.add_child(listener(source, prop, args))
		return l
	
	func object_view(source: Object):
		for prop in source.get_property_list():
			if "usage" in prop and prop.usage & PROPERTY_USAGE_EDITOR:
				property(source, prop.name)
	
	func accessor(source: Object, method: String, arguments:= []) -> Label:
		return property(source, method, arguments)
	
	func listener(source: Object, prop: String, args) -> LabelListener:
		var ls := LiveDebug.dry('LabelListener') as LabelListener
		if !ls:
			ls = LabelListener.new()
		ls.source = source
		ls.property = prop
		ls.arguments = args
		return ls
	
	func clear():
		LiveDebug.swim(panel)
		LiveDebug.swim(box)

@onready var pause_button: CheckBox = $PanelContainer/VBoxContainer/HBoxContainer/pause
@onready var frames_counter:Label = $PanelContainer/VBoxContainer/framerate
var debug_box: Box = null
var active := false
var average_ms := 0.0

func _init():
	pool = {}

func _ready():
	set_physics_process(false)
	pause_button.toggled.connect(_on_pause_toggled)
	set_active(false)

func set_active(a: bool):
	active = a
	visible = active
	set_process(a)
	if a:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_on_pause_toggled(TimeManagement.paused)
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event: InputEvent):
	if event.is_action_pressed('toggle_live_debug'):
		set_active(!active)
	elif active:
		if event is InputEventMouseButton and event.is_pressed() and (
			event.button_index == MOUSE_BUTTON_MIDDLE
		):
			col_request = event.position
			set_physics_process(true)

func _process(delta: float) -> void:
	var ms := delta*1000
	average_ms = (ms + average_ms)/2
	frames_counter.text = 'frame time: %4.2f | %4.2f' % [ms, average_ms]

func _get_object(uv: Vector2) -> Node:
	var cam := get_viewport().get_camera_3d()
	var phys:PhysicsDirectSpaceState3D = Global.get_world()
	assert(phys)
	var q := PhysicsRayQueryParameters3D.new()
	q.from = cam.project_ray_origin(uv)
	q.to = q.from + cam.project_ray_normal(uv)*10000
	q.collide_with_areas = true
	var col := phys.intersect_ray(q)
	if col:
		return col.collider
	else:
		return null

func _physics_process(_delta:float):
	var obj := _get_object(col_request)
	if obj:
		if debug_box:
			debug_box.clear()
		debug_box = show_info(obj, col_request)
	set_physics_process(false)

func show_info(obj: Node, window_pos: Vector2):
	var box := get_box()
	add_child(box.panel)
	if !obj:
		var _y = box.add_label('No Content')
		return
	box.add_label(obj.get_path())
	if obj.has_method('_show_debug'):
		obj._show_debug(box)
	else:
		var p := obj.get_parent()
		while(p):
			if p.has_method('_show_debug'):
				break
			else:
				p = p.get_parent()
		if p:
			p._show_debug(box)
		else:
			box.add_label("Top-level node")
	box.panel.show()
	box.panel.set_global_position(window_pos)
	return box

func get_box() -> Box:
	var panel = dry('PanelContainer')
	if !panel:
		panel = PanelContainer.new()
	return Box.new(panel)

func swim(c: Node):
	for c2 in c.get_children():
		swim(c2)
	for c2 in c.get_children():
		c.remove_child(c2)

	# This has to be overridden for custom classes
	var clname: String = c.get_class()
	if !(clname in pool):
		pool[clname] = []
	pool[clname].append(c)

func dry(c_name: String):
	if c_name in pool:
		return pool[c_name].pop_back()
	else:
		return null

func _on_pause_toggled(pause: bool):
	if !is_inside_tree():
		return
	TimeManagement.paused = pause
	var player = Global.get_player()
	if !player or !player.cam_rig:
		return
	if pause:
		player.cam_rig.process_mode = PROCESS_MODE_ALWAYS
	else:
		player.cam_rig.process_mode = PROCESS_MODE_PAUSABLE
