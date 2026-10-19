class_name Membrane

var _composition : Dictionary[Substance, float] #components
var _inside : Fluid
var _outside : Fluid
var _flux_report : Dictionary[Substance, Array] #substance : [flux, nernst]

var permeability_rate : float = 1e-6
const leak_permeation_speed : float = 3e-3
const facilitated_permeation_speed : float = 1e-4
var _channel_permeabilities : Dictionary

const carrier_speed : float = 0.00005
var membrane_potential : float = 0.0
var _water_permeability : float = 0.05
var _carrier_flux : Dictionary[Substance, float]
var _pump_total_charge_flux : float
var _numerator : float
var _denominator : float
var _carriers : Array
var _aa_carriers : Array #sadly, there is a special case for amino acids.

func _init(inside : Fluid, outside : Fluid):
	_inside = inside
	_outside = outside
	membrane_potential = -0.081

func fill(comp : Dictionary[String, float]):
	for c in comp:
		_composition[Substance.fetch(c)] = comp[c]

func get_flux_report(subs : Substance) -> Array:
	return _flux_report.get(subs, [0, 0, 0, 0])

func get_leak_permeability(subs : Substance) -> float:
	var mass := subs.mass/100
	var size_coefficient = pow(maxf(2.0-mass, 0)/2.0, 4) #things larger than 200 Da can't pass at all
	var arbitrary_coefficient = 1.1-(subs.charge*(1-clamp(absf(0.22-mass), 0, 1)))
	
	var lipid_permeability = size_coefficient*arbitrary_coefficient*leak_permeation_speed
	return lipid_permeability

func get_permeability(subs : Substance) -> float:
	var leak = get_leak_permeability(subs)
	var facilitated = _channel_permeabilities.get(subs, 0.0)
	
	return (leak + facilitated) * permeability_rate

func tick():
	_carrier_flux.clear()
	_pump_total_charge_flux = 0
	var concentration_difference := Fluid.concentration_gradient(_outside, _inside)
	_carry(concentration_difference)
	
	var previous_membrane_potential = membrane_potential
	membrane_potential = 0
	_numerator = 1e-16
	_denominator = 1e-16
	_permeate(previous_membrane_potential, concentration_difference)
	membrane_potential = Units.RT_F*log(_numerator/_denominator)
	membrane_potential += _pump_total_charge_flux*Units.membrane_base_input_resistance
	#print(snappedf(membrane_potential, 0.001), " ", \
	#snappedf(_pump_total_charge_flux*Units.membrane_base_input_resistance, 0.001))

func _permeate(previous_membrane_potential : float, concentration_difference : Dictionary[Substance, Array]):
	_flux_report.clear()
	var total_inside_concentration : float = 0
	var total_outside_concentration : float = 0
	for subs in concentration_difference:
		var conc = concentration_difference[subs]
		var Cout = conc[0]
		var Cin = conc[1]
		var permeability = get_permeability(subs)
		var net_flux : float
		var passive_flux : float
		var active_flux : float = 0
		var nernst_potential : float
		
		if subs.charge != 0:
			#full ghk
			var u : float = subs.charge * previous_membrane_potential / Units.RT_F
			if absf(u) < 1e-6:
				passive_flux = permeability * (Cout - Cin)       # limit as V → 0
			else:
				var e = exp(-u)
				passive_flux = -permeability * u * (Cin - Cout*e) / (1.0 - e)   # inward positive
			nernst_potential = (Units.RT_F / subs.charge) * log(maxf(Cout,1e-12) / maxf(Cin,1e-12))
			#print(subs.name, " ", passive_flux)
			
			if subs.charge > 0:
				_numerator += permeability*Cout
				_denominator += permeability*Cin
			else:
				_denominator += permeability*Cout
				_numerator += permeability*Cin
		else:
			passive_flux = permeability*(Cout-Cin)
			nernst_potential = NAN
		
		active_flux += _carrier_flux.get(subs, 0.0)
		net_flux = (active_flux + passive_flux) * Petri.acc
		
		_flux_report[subs] = [net_flux, nernst_potential, active_flux, passive_flux]
		
		var outside_remaining = _outside.add_substance(subs, -net_flux)
		var inside_remaining = _inside.add_substance(subs, net_flux)
		
		#removed more than a container had, since there is no negative concentration
		#we have to remove the excess from the one who would've gained non-existing substance
		#add_substance function already dealt with the negative value, no need to worry.
		if outside_remaining < 0.0:
			_inside.add_substance(subs, outside_remaining)
		if inside_remaining < 0.0:
			_outside.add_substance(subs, inside_remaining)
		
		total_inside_concentration += Cin
		total_outside_concentration += Cout
	
	var water_driving_force = total_inside_concentration - total_outside_concentration
	var water_flux = clampf(_water_permeability * water_driving_force * Petri.acc * 1e-8 * (4.0/Petri.tps), -_inside.volume/10, _inside.volume/10)
	_outside.volume -= water_flux
	_inside.volume += water_flux

func _carry(concentration_difference : Dictionary[Substance, Array]):
	for c in _carriers:
		var maximum_rate = c[0]
		var atp_usage = c[1]
		var ports = c[2]
		
		#calculate total activation, energy cost and charge_moved (all per cycle)
		var total_activation : float = 1.0
		var charge_moved : int = 0
		var energy_cost : float = 0.0
		for subs_data in ports:
			var subs : Substance = subs_data[0]
			var stoichiometry : int = subs_data[1]
			var K : float = subs_data[2] #half_saturation_constant
			
			var concentrations : Array = concentration_difference[subs]
			var Cout = maxf(concentrations[0], 1e-12)
			var Cin = maxf(concentrations[1], 1e-12)
			
			charge_moved += stoichiometry*subs.charge
			energy_cost -= stoichiometry*(Units.RT_F*log(Cout/Cin) - subs.charge*membrane_potential)
			
			#activation calculation
			var C : float = Cout if stoichiometry > 0 else Cin
			var activation := pow(C/(K+C), absi(stoichiometry))
			
			total_activation = total_activation * activation
		
		const Eatp = 0.570 #Energy supplied by each atp molecule in volts
		var net_energy = energy_cost-atp_usage*Eatp # volts, negative = favorable
		var driving = maxf(1.0 - exp(minf(net_energy / Units.RT_F, 20.0)), -1.0)
		
		var reaction_rate = carrier_speed*maximum_rate*total_activation*driving*(4.0/Petri.tps)
		_pump_total_charge_flux += charge_moved*reaction_rate
		
		#do actual carrying now
		for subs_data in ports:
			var subs : Substance = subs_data[0]
			var stoichiometry : int = subs_data[1]
			var _K : float = subs_data[2] #half_saturation_constant
			var existing_flux = _carrier_flux.get_or_add(subs, 0.0)
			_carrier_flux[subs] = existing_flux + reaction_rate*stoichiometry
	_amino_acid_carry(concentration_difference) #yep, just like that.

func _amino_acid_carry(concentration_difference : Dictionary[Substance, Array]):
	if _aa_carriers.is_empty():
		return
	
	var aa_out := 0.0
	var aa_in := 0.0
	for aa in Peptide.AMINO_POOL:
		var concentrations = concentration_difference.get(aa)
		if !(concentrations is Array): continue
		aa_out += concentrations[0]
		aa_in += concentrations[1]
	aa_out = maxf(aa_out, 1e-12)
	aa_in = maxf(aa_in, 1e-12)
	
	for c in _aa_carriers:
		var maximum_rate : float = c[0]
		var subs : Substance = c[1]
		var stoichiometry : int = c[2]
		var K_subs : float = c[3]
		var K_amino : float = c[4]
		
		var subs_concentrations = concentration_difference[subs]
		
		var Cout := maxf(subs_concentrations[0], 1e-12)
		var Cin := maxf(subs_concentrations[1], 1e-12)
		
		# energy cost per cycle in volts (same convention as _carry; amino acid is neutral, +1 inward)
		var energy_cost = \
		-stoichiometry * \
		(Units.RT_F * log(Cout / Cin) - subs.charge * membrane_potential) \
		- Units.RT_F * log(aa_out / aa_in)
		
		var driving := maxf(1.0 - exp(minf(energy_cost / Units.RT_F, 20.0)), -1.0)
		
		# binding sides depend on stoichiometry of travel
		var aC : float = aa_out if driving > 0 else aa_in
		var sC : float = Cout if driving*stoichiometry > 0 else Cin
		
		var activation : float= pow(sC / (K_subs + sC), absi(stoichiometry)) \
				* (aC / (K_amino + aC))
		var reaction_rate : float = carrier_speed*maximum_rate*activation*driving*(4.0/Petri.tps)
		
		_pump_total_charge_flux += stoichiometry * subs.charge * reaction_rate
		_carrier_flux[subs] = _carrier_flux.get(subs, 0.0) + stoichiometry * reaction_rate
		
		# one amino acid per cycle, split by share of the source side
		var side := 0 if reaction_rate > 0.0 else 1
		var source_total := aa_out if reaction_rate > 0.0 else aa_in
		for aa in Peptide.AMINO_POOL:
			var concentrations = concentration_difference.get(aa)
			if concentrations == null: continue
			var share : float = concentrations[side] / source_total
			_carrier_flux[aa] = _carrier_flux.get(aa, 0.0) + reaction_rate * share

func increase_permeability(subs : Substance, amount : float):
	var current_amount = _channel_permeabilities.get(subs, 0.0)
	_channel_permeabilities[subs] = current_amount + amount*facilitated_permeation_speed

func increase_water_permeability(amount : float):
	_water_permeability += amount

func add_carrier(maximum_rate : float, atp_usage : float, ports : Array):
	_carriers.append([maximum_rate, atp_usage, ports])

func add_aa_carrier(mr : float, s: Substance, d : float, Ks : float, Ka: float):
	_aa_carriers.append([mr, s, d, Ks, Ka])

func divide() -> Fluid:
	var donated : Dictionary[String, float]
	for n in _composition:
		var new_amount = _composition[n]/2
		_composition[n] = new_amount
		donated[n.name] = new_amount
	var sibling := Fluid.new(Units.cell_volume)
	sibling.fill(donated)
	return sibling
