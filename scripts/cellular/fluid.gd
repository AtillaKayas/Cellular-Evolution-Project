class_name Fluid

var volume : float

var _solutes : Dictionary[Substance, float]

func _init(vol : float):
	volume = vol

func section(sect_volume : float, gradient : Dictionary[String, float] = {}):
	#in gradient the value is new_fluid_molarity/old_fluid_molarity
	
	sect_volume = clampf(sect_volume, 0, volume)
	var new_fluid = Fluid.new(sect_volume)
	if volume == 0 or sect_volume == 0:
		return new_fluid #no point in doing anything
	var ratio = sect_volume/volume
	for s in _solutes:
		var g_ratio : float = maxf(gradient.get(s.name, 1.0), 0)
		var amount = _solutes[s]
		var amount_to_other = minf(g_ratio*ratio*amount, amount)
		var amount_to_self = amount-amount_to_other
		
		new_fluid._solutes[s] = amount_to_other
		_solutes[s] = amount_to_self
	
	volume -= sect_volume
	return new_fluid

func add_substance(subs : Substance, femtomoles : float) -> float:
	#returns the final substance amount
	#accepts negative values and returns negative if more was removed than existing
	
	#if 0, then there is no point in doing the other operations
	if femtomoles == 0.0:
		return _solutes.get(subs, 0.0)
	
	if !subs in _solutes:
		_solutes[subs] = femtomoles
	else:
		_solutes[subs] += femtomoles
	
	var current_amount = _solutes[subs]
	if _solutes[subs] <= 0.0:
		_solutes.erase(subs)
	
	return current_amount
		

func remove_substance(subs : Substance, femtomoles : float) -> float:
	return add_substance(subs, -femtomoles)

func set_substance(subs : Substance, femtomoles : float):
	_solutes[subs] = femtomoles

func get_concentration(subs : Substance) -> float:
	return _solutes.get(subs, 0.0)

func fill(solutes : Dictionary[String, float]):
	_solutes.clear()
	for s in solutes:
		_solutes[Substance.fetch(s)] = solutes[s]

func remove_mass(substances : Dictionary[Substance, float], multiplier : float):
	for subs in substances:
		var reserve = _solutes.get(subs, 0)
		var removed_amount = substances[subs]*multiplier*Units.molecule_count_to_milimolars_in_cell_volume
		_solutes[subs] = maxf(reserve - removed_amount, 0)

func clear():
	_solutes.clear()

func _to_string() -> String:
	return str(_solutes)

func _to_concentration(amount : float):
	var molarity = amount/volume
	return str(snappedf(molarity, 0.001)) + " mM"

static func concentration_gradient(f1 : Fluid, f2 : Fluid) -> Dictionary[Substance, Array]:
	var result : Dictionary[Substance, Array]
	for s in f1._solutes:
		result[s] = [f1._solutes[s]/f1.volume, 0.0] 
	
	for s in f2._solutes:
		var arr = result.get_or_add(s, [0.0, 0.0])
		arr[1] = f2._solutes[s]/f2.volume
	return result

func get_all_concentrations() -> Dictionary[Substance, String]:
	var result : Dictionary[Substance, String] = {}
	for subs in _solutes:
		result[subs] = _to_concentration(_solutes[subs])
	return result

func display_concentration(subs : Substance) -> String:
	return _to_concentration(get_concentration(subs))
