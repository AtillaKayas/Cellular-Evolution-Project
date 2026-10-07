class_name Petri extends Screen

var tps : int = 4 #ticks per second
var _elapsed_time : float = 0 #used by delta of the _process()
var _last_cell_id : int = 0

var fluid := Fluid.new()
var _cells : Array[Cell]
var _selected_cell : Cell :
	set(value):
		_selected_cell = value
		selected_cell_changed.emit(value)

signal selected_cell_changed(cell : Cell)

func _ready():
	generate_basic()
	Global.petri = self

func _process(delta: float) -> void:
	_elapsed_time += delta
	if _elapsed_time > (1.0/tps):
		_elapsed_time = 0
		_tick()

func register(cell : Cell) -> void:
	_cells.append(cell)
	cell.name = "#" + str(_last_cell_id)
	_last_cell_id += 1
	_selected_cell = cell

func get_selected_cell() -> Cell:
	return _selected_cell

func generate_basic():

	fluid.volume = Units.petri_volume
	
	var fill : Dictionary[String, float] = {
		"k" : 005.0*Units.petri_volume, #everything in femtomoles (milimolar * picoliter = femtomole)
		"n" : 150.0*Units.petri_volume,
		"l" : 125.0*Units.petri_volume
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
	for cell in _cells:
		cell.tick()
