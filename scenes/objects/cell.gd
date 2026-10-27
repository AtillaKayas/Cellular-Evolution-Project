class_name Cell

#nucleins
static var default_starter_nuclein = \
	Nuclein.PROMOTER + Nuclein.pep_to_seq("AAICLONAA") + Nuclein.TERMINATOR + \
	#K Channel
	Nuclein.PROMOTER + Nuclein.pep_to_seq("AOCABAAK") + Nuclein.TERMINATOR + \
	#Cl Channel
	Nuclein.PROMOTER + Nuclein.pep_to_seq("AJCABNAC") + Nuclein.TERMINATOR + \
	#Na Channel
	Nuclein.PROMOTER + Nuclein.pep_to_seq("AFCABIAN") + Nuclein.TERMINATOR + \
	
	#K-Na Pump
	Nuclein.PROMOTER + Nuclein.pep_to_seq("AFCABMFKLKNAE") + Nuclein.TERMINATOR + \
	#KCC Exchanger
	Nuclein.PROMOTER + Nuclein.pep_to_seq("AFCABAFKHKCHE") + Nuclein.TERMINATOR + \
	#Na-Amino Acid Exchanger
	Nuclein.PROMOTER + Nuclein.pep_to_seq("AFACIMFNILF") + Nuclein.TERMINATOR + \
	
	#Aquaporin
	Nuclein.PROMOTER + Nuclein.pep_to_seq("AFFLOODA") + Nuclein.TERMINATOR + \
	
	#ADP Synthase
	Nuclein.PROMOTER + Nuclein.pep_to_seq("AFDEFAEACEADDFBAAAFBA") + Nuclein.TERMINATOR + \
	#Glycolysis Enzyme
	Nuclein.PROMOTER + Nuclein.pep_to_seq("AJGLIEM") + Nuclein.TERMINATOR + \
	#Glucose Channel
	Nuclein.PROMOTER + Nuclein.pep_to_seq("AOCABOAG") + Nuclein.TERMINATOR + \
	#Hexokinase
	Nuclein.PROMOTER + Nuclein.pep_to_seq("AIKINAEPG") + Nuclein.TERMINATOR + \
	
	#Cyclin
	Nuclein.PROMOTER + Nuclein.pep_to_seq("AFCCNDL") + Nuclein.TERMINATOR


var name : String
var _petri : Petri
var petri_object : PetriObject

var _cytosol : Fluid
var _membrane : Membrane
var _proteome : Proteome
var _genome : Genome

var confidence : float #a cell with a confidence of 100% divides
var _old_volume : float


const rng_seed : int = 52435261132
static var _rng = RandomNumberGenerator.new()

var _chem : Chemistry
var _states : Array[Chemistry]

func _init(petri : Petri, petri_obj : PetriObject, cell_name : String, genome : Genome, cytosol):
	_petri = petri
	petri_object = petri_obj
	name = cell_name
	_genome = genome
	_cytosol = cytosol
	_membrane = Membrane.new(_cytosol, petri.fluid)
	_old_volume = _cytosol.volume
	_new_chemistry()

func tick():
	if _chem == null: return
	_chem.tick(_cytosol, _membrane)
	
	if confidence > 0:
		confidence -= 0.0000001 * Petri.acc * (4.0/Petri.tps)
	confidence = maxf(confidence, 0)
	if confidence > 1:
		_divide()

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

func _divide():
	confidence = 0
	var new_fluid = _cytosol.section(_cytosol.volume/2)
	var dir := Vector2.from_angle(randf() * TAU)
	var offset = dir * (Units.volume_to_radius(get_volume()) + Units.volume_to_radius(new_fluid.volume))
	var new_genome = _genome.replicate()
	var pos = petri_object.get_transform().origin + offset
	_petri.add_cell(pos, new_fluid.volume, "", new_genome, new_fluid)

#################
####getters
##################
func get_cytosol_data() -> Dictionary[Substance, String]:
	var result : Dictionary[Substance, String]
	var concentrations = _cytosol.get_all_concentrations()
	for subs in concentrations:
		result[subs] = str(subs) + ": " + concentrations[subs]
	
	return result

func get_genome_data() -> Array[Nuclein]:
	return _genome.get_nucleins()

func get_cytosol_substance_concentration(subs : Substance) -> String:
	return _cytosol.display_concentration(subs)

func get_extracellular_substance_concentration(subs : Substance) -> String:
	return _petri.fluid.display_concentration(subs)

func get_flux_report(subs : Substance) -> Array:
	return _membrane.get_flux_report(subs)

func get_membrane_permeability(subs : Substance) -> String:
	return Units.to_scientific_notation(_membrane.get_permeability(subs), 1)

func get_membrane_potential() -> float:
	return _membrane.membrane_potential

func get_volume() -> float:
	return _cytosol.volume

func get_volume_difference() -> float:
	return absf(get_volume() - _old_volume) / maxf(_old_volume, 1e-9)

func save_volume():
	_old_volume = get_volume()

func get_peptide_amount(peps : Peptide) -> float:
	return _proteome.get_peptide_amount(peps)
