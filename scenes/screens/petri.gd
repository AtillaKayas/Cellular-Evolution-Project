class_name Petri extends Screen


const rng_seed : int = 52435261132
static var _rng : RandomNumberGenerator
static var tps : int = 20 #ticks per second
static var acc : float = 900 #simulated seconds per real second
var _elapsed_time : float = 0 #used by delta of the _process()

var _ps := PhysicsServer2D
var _rs := RenderingServer

var _cell_texture_res := preload("res://sprites/cell.png")
var _last_cell_id : int = 0
var _cells : Dictionary[String, Cell]
var _selected_cell : Cell :
	set(value):
		_selected_cell = value
		selected_cell_changed.emit(value)

var fluid := Fluid.new(Units.petri_volume)

signal selected_cell_changed(cell : Cell)

static func _static_init():
	_rng = RandomNumberGenerator.new()
	_rng.set_seed(rng_seed)

func _ready():
	generate_basic()
	Global.petri = self
	var _starter_nucleins : Array[Nuclein] = [Nuclein.new("MAIN", Cell.default_starter_nuclein + _generate_random_protein_bulk())]
	var starter_genome = Genome.new(_starter_nucleins)
	
	var starter_fluid = fluid.section(Units.cell_volume, {
			"k" : 30.0,
			"n" : 0.1,
			"l" : 0.0416,
			"A" : 300.0,
			"G" : 250.0
		}
	)
	starter_fluid.add_substance(Substance.fetch("appp"), 5*Units.cell_volume)
	starter_fluid.add_substance(Substance.fetch("app"), 0.5*Units.cell_volume)
	starter_fluid.add_substance(Substance.fetch("p"), 1*Units.cell_volume)
	
	add_cell(Vector2(600, 300), Units.cell_volume, "", starter_genome, starter_fluid)

func _process(delta: float) -> void:
	_elapsed_time += delta
	if _elapsed_time > (1.0/tps):
		_elapsed_time = 0
		_tick()

func get_selected_cell() -> Cell:
	return _selected_cell

func generate_basic():

	fluid.volume = Units.petri_volume
	
	var fill : Dictionary[String, float] = {
		"k" : 005.0*Units.petri_volume, #everything in femtomoles (milimolar * picoliter = femtomole)
		"n" : 150.0*Units.petri_volume,
		"l" : 125.0*Units.petri_volume,
		"g" : 010.0*Units.petri_volume,
	}
	#amino acids
	for i in 16:
		var letter = char(65 + i)
		fill[letter] = 3.0/16.0*Units.petri_volume
	for i in 4:
		var letter = char(97 + i)
		fill[letter] = 1.0*Units.petri_volume
	
	fluid.fill(fill)
	

func _tick():
	for cell_name in _cells:
		var cell = _cells[cell_name]
		cell.tick()
		
		var radius := Units.volume_to_radius(cell.get_volume())
		cell.petri_object.sync_visual(radius)
		
		if cell.get_volume_difference() > 0.05:
			_ps.shape_set_data(cell.petri_object.get_shape(), radius)
			cell.save_volume()


############################
##CELL MANAGEMENT
############################

func add_cell(pos : Vector2, volume : float, cell_name : String, genome : Genome, cytosol : Fluid) -> Cell:
	var radius = Units.volume_to_radius(volume)
	
	var transform = Transform2D(0, pos)
	var rect = Rect2(-0.5, -0.5, 1, 1)
	
	var body = _ps.body_create()
	_ps.body_set_space(body, get_world_2d().space)
	
	var shape := _ps.circle_shape_create()
	_ps.shape_set_data(shape, radius)
	_ps.body_add_shape(body, shape)
	
	_ps.body_set_state(body, PhysicsServer2D.BODY_STATE_TRANSFORM, transform)
	_ps.body_set_mode(body, PhysicsServer2D.BODY_MODE_RIGID)
	_ps.body_set_param(body, PhysicsServer2D.BODY_PARAM_GRAVITY_SCALE, 0.0)
	_ps.body_set_param(body, PhysicsServer2D.BODY_PARAM_LINEAR_DAMP, 8.0)
	_ps.body_set_param(body, PhysicsServer2D.BODY_PARAM_ANGULAR_DAMP, 8.0)
	_ps.body_set_param(body, PhysicsServer2D.BODY_PARAM_MASS, volume)
	
	var visual = _rs.canvas_item_create()
	_rs.canvas_item_set_parent(visual, get_canvas_item())
	_rs.canvas_item_add_texture_rect(visual, rect, _cell_texture_res.get_rid())
	_rs.canvas_item_set_transform(visual, transform)
	
	if cell_name == "" or cell_name in _cells:
		cell_name = _get_generic_cell_name()
	
	var petri_object = PetriObject.new(body, visual, shape)
	var cell = Cell.new(self, petri_object, cell_name, genome, cytosol)
	
	if _cells.is_empty(): _selected_cell = cell
	
	_cells[cell_name] = cell
	return cell

func remove_cell(cell_name : String):
	var cell = _cells.get(cell_name)
	if cell == null: return
	_cells.erase(cell_name)
	
	cell.petri_object.destroy()

func _get_generic_cell_name() -> String:
	_last_cell_id += 1
	
	var draft_name = "#" + str(_last_cell_id)
	if draft_name in _cells:
		draft_name = _get_generic_cell_name()
	return draft_name

func _exit_tree() -> void:
	for cell_name in _cells:
		var cell = _cells[cell_name]
		cell.petri_object.destroy()
	_cells.clear()

static func _generate_random_protein_bulk() -> String:
	const chars = "abcd"
	var result = ""
	
	for n in 50:
		var gibberish : String = ""
		for m in _rng.randi_range(8, 48):
			gibberish = gibberish + chars[_rng.randi() % 4]
		result += Nuclein.PROMOTER + gibberish + Nuclein.TERMINATOR
		for m in _rng.randi_range(0, 16):
			result = result + chars[_rng.randi() % 4]
	return result
