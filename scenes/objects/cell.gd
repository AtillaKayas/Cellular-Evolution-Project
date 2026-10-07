class_name Cell extends Node2D

@onready var _tml : TileMapLayer = $".."
@onready var _petri : Petri = $"../.."

var _cytosol : Fluid
var _membrane : Membrane
var _proteome : Proteome
var _genome : Genome

var grid_pos : Vector2i

const rng_seed : int = 52435261132
static var _rng = RandomNumberGenerator.new()

var _chem : Chemistry
var _states : Array[Chemistry]

func tick():
	if _chem == null: return
	_chem.tick(_cytosol, _membrane)

func _new_chemistry():
	#go through existing chemistries (stored in _states) to see if any of them match with the current composition
	#if none of them match, then create a new one.
	for c in _states:
		if c.matches(_proteome):
			_chem = c
			return
	_chem = Chemistry.new(self, _cytosol, _membrane)
	_states.append(_chem)
	
	_chem.count(_cytosol._solutes)
	_proteome = _chem.translation(_cytosol, _genome)

#################
####getters
##################
func get_cytosol_data() -> Dictionary[Substance, String]:
	var result : Dictionary[Substance, String]
	var concentrations = _cytosol.get_all_concentrations()
	for subs in concentrations:
		result[subs] = str(subs) + ": " + concentrations[subs]
	
	
	return result

func get_cytosol_substance_concentration(subs : Substance) -> String:
	return _cytosol.get_concentration(subs)

func get_extracellular_substance_concentration(subs : Substance) -> String:
	return _petri.fluid.get_concentration(subs)

func get_flux_report(subs : Substance) -> Array:
	return _membrane.get_flux_report(subs)

func get_membrane_permeability(subs : Substance) -> String:
	return Units.to_scientific_notation(_membrane.get_permeability(subs), 1)

func get_membrane_potential() -> float:
	return _membrane.membrane_potential
















####################
#start functions
####################

func _ready():
	grid_pos = _tml.local_to_map(position)
	_petri.register(self)
	generate_basic()
	_new_chemistry()

func generate_basic():
	
	#for i in range(0, 16):
	#	print(char(i+65), " ", pow(1.59, i))
	
	
	#for x in range(1, 17):
	#	var normalization = x/8.0
	#	var permeability = pow(10, normalization)
	#	print(x, " ", permeability)
	
	
	_rng.set_seed(rng_seed)
	
	_cytosol = Fluid.new()
	_membrane = Membrane.new(_cytosol, _petri.fluid)
	_cytosol.volume = Units.cell_volume
	
	var fill : Dictionary[String, float] = {
		"k" : 150.0*Units.cell_volume, #everything in femtomoles (milimolar * picoliter = femtomole)
		"n" : 015.0*Units.cell_volume,
		"l" : 005.2*Units.cell_volume 
	}
	
	#var fill : Dictionary[String, float] = {
	#	"k" : 155.0*Units.cell_volume,
	#	"n" : 010.0*Units.cell_volume,
	#	"l" : 005.0*Units.cell_volume 
	#}
	
	#amino acids
	for i in 16:
		var letter = char(65 + i)
		fill[letter] = 3.0/16.0*Units.cell_volume
	for i in 4:
		var letter = char(97 + i)
		fill[letter] = 1.0*Units.cell_volume
	
	#nucleins
	var main = Nuclein.PROMOTER + Nuclein.pep_to_seq("AAICLONAA") + Nuclein.TERMINATOR
	main += Nuclein.PROMOTER + Nuclein.pep_to_seq("AOCABAAK") + Nuclein.TERMINATOR #Pot
	main += Nuclein.PROMOTER + Nuclein.pep_to_seq("AJCABNAC") + Nuclein.TERMINATOR #Chl
	main += Nuclein.PROMOTER + Nuclein.pep_to_seq("AFCABIAN") + Nuclein.TERMINATOR #Sod
	#main += Nuclein.PROMOTER + Nuclein.pep_to_seq("AFIBMBFKFNK") + Nuclein.TERMINATOR 
	main += Nuclein.PROMOTER + Nuclein.pep_to_seq("AFCABMFKLKNAE") + Nuclein.TERMINATOR 
	#main += Nuclein.PROMOTER + Nuclein.pep_to_seq("AFCABOFKHKCHE") + Nuclein.TERMINATOR 
	main += _generate_random_protein_bulk()

	_cytosol.fill(fill)
	var plasmid : Dictionary[Nuclein, int] = {Nuclein.new(main) : 1}
	_genome = Genome.new(plasmid)
	
	#fill = {
	#	"pzz" : 1.25 #everything in milimolars, assuming the cell volume is relevant for the membrane
	#}
	
	#_membrane.fill(fill)

#####################
#static privates
####################

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
