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
var _pumped_substances : Array #Pump1Ion1, Pump1Ion2, Pump1Speed, Pump2Ion1, Pump2Ion2, Pump2Speed...
var _pump_flux : Dictionary[Substance, float]
var _carrier_flux : Dictionary[Substance, float]
var _pump_total_charge_flux : float
var _numerator : float
var _denominator : float
var _carriers : Array

func _init(inside : Fluid, outside : Fluid):
	_inside = inside
	_outside = outside
	membrane_potential = -0.081

func fill(comp : Dictionary[String, float]):
	comp.clear()
	for c in comp:
		_composition[Substance.fetch(c)] = comp[c]

func get_flux_report(subs : Substance) -> Array:
	return _flux_report.get(subs, [])

func get_leak_permeability(subs : Substance) -> float:
	var size_coefficient = pow(maxf(2.0-subs.mass, 0)/2.0, 4) #things larger than 200 Da can't pass at all
	var arbitrary_coefficient = 1.1-(subs.charge*(1-clamp(absf(0.22-subs.mass), 0, 1)))
	
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
	_numerator = 0
	_denominator = 0
	_permeate(previous_membrane_potential, concentration_difference)
	membrane_potential = Units.RT_F*log(_numerator/_denominator)
	membrane_potential += _pump_total_charge_flux*Units.membrane_base_input_resistance
	#print(snappedf(membrane_potential, 0.001), " ", \
	#snappedf(_pump_total_charge_flux*Units.membrane_base_input_resistance, 0.001))

func _permeate(previous_membrane_potential : float, concentration_difference : Dictionary[Substance, Array]):
	_flux_report.clear()
	for subs in concentration_difference:
		var conc = concentration_difference[subs]
		var Cout = conc[0]
		var Cin = conc[1]
		var permeability = get_permeability(subs)
		var net_flux : float
		var passive_flux : float
		var active_flux : float
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
		
		active_flux = _pump_flux.get(subs, 0.0)
		active_flux += _carrier_flux.get(subs, 0.0)
		net_flux = active_flux + passive_flux
		
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
		
		var reaction_rate = carrier_speed*maximum_rate*total_activation*driving
		_pump_total_charge_flux += charge_moved*reaction_rate
		
		#do actual carrying now
		for subs_data in ports:
			var subs : Substance = subs_data[0]
			var stoichiometry : int = subs_data[1]
			var _K : float = subs_data[2] #half_saturation_constant
			var existing_flux = _carrier_flux.get_or_add(subs, 0.0)
			_carrier_flux[subs] = existing_flux + reaction_rate*stoichiometry

func clear():
	_pumped_substances.clear()

func increase_permeability(subs : Substance, amount : float):
	var current_amount = _channel_permeabilities.get(subs, 0.0)
	_channel_permeabilities[subs] = current_amount + amount*facilitated_permeation_speed

func add_pump(maximum_rate : float, ion1 : Substance, Kion1 : float, ion2 : Substance, Kion2 : float):
	_pumped_substances.append(maximum_rate)
	_pumped_substances.append(ion1)
	_pumped_substances.append(Kion1)
	_pumped_substances.append(ion2)
	_pumped_substances.append(Kion2)

func add_carrier(maximum_rate : float, atp_usage : float, ports : Array):
	_carriers.append([maximum_rate, atp_usage, ports])



#code below is to make ion permeabilities perfect
#getting the K flux / Na flux to -0.66666666 is the goal, if we do so we can
#make a system in equilibrium with a pump and passive leaks

#static func _static_init() -> void:
#	var best = _attempt_matching_permeabilities(1750, 800, 40)
	#for n in 100:
	#	var prev = best
	#	print(n, ": ---------------------------------------")
	#	best = _attempt_matching_permeabilities(( 20*best + prev ) / 21, 800, 40)
	#	if best < 0: return

#static func _attempt_matching_permeabilities(Pk : float, Pc : float, Pn : float) -> float:
#	var ghk = func(charge, Cin, Cout, permeability, Vm):
#		var constant = charge*Vm/Units.RT_F
#		var e = exp(-constant)
#		var gradient = (Cin-Cout*e)/(1-e)
#		var passive_flux = -permeability*Units.faraday*charge*constant*gradient
#		#var nernst_potential = (Units.RT_F/charge)*log(Cout/Cin)
#		#print(nernst_potential)
#		return passive_flux
#	
#	Pk = Pk*Membrane.facilitated_permeation_speed*1e-6
#	Pc = Pc*Membrane.facilitated_permeation_speed*1e-6
#	Pn = Pn*Membrane.facilitated_permeation_speed*1e-6
#	var Kin : float = 150.0
#	var Nin : float = 15.0
#	var Chin : float = 10.0
#	var Kout : float = 005.0
#	var Nout : float = 150.0
#	var Chout : float = 125.0
#	
#	#Vm calculation
#	var _d := Pk*Kin + Pn*Nin + Pc*Chout
#	var _n := Pk*Kout + Pn*Nout + Pc*Chin
#	var Vm = Units.RT_F*log(_n/_d)
#	
#	#Contribution of pump (calculated via Sodium's flux)
#	var Fn = ghk.call(+1, Nin, Nout, Pn, Vm)
#	var pump_contribution = Fn*membrane_base_input_resistance/3.0
#	Vm -= pump_contribution
#	
#	#Fluxes
#	var Fk = ghk.call(+1, Kin, Kout, Pk, Vm)
#	Fn = ghk.call(+1, Nin, Nout, Pn, Vm)
#	var Fc = ghk.call(-1, Chin, Chout, Pc, Vm)
#	
#	print("Potassium Permeability: ", snappedf(Pk/(Membrane.facilitated_permeation_speed*1e-6), 0.1))
#	print("Vm: ", snappedf(Vm, 0.001), " Flux K: ", snappedf(Fk, 0.001), " Flux Na: ", snappedf(Fn, 0.001), " Flux Cl: ", snappedf(Fc, 0.001))
#	print("Pump Flux: ", snappedf(Fn, 0.001), " Pump Contribution: ", snappedf(pump_contribution, 0.001), " Pump Recalculated: ", snappedf(Fn*membrane_base_input_resistance, 0.001))
#	print("F_K/F_Na: ", snappedf(Fk/Fn, 0.000000001))
#	var X = (Fk/Pk)/(Fn/Pn)
#	#print("X_K/X_Na: ", snappedf(X, 0.001))
#	var best = Pn*(-2.0/3.0)/X
#	best = best/(Membrane.facilitated_permeation_speed*1e-6)
#	print("Best P_K: ", snappedf(best, 0.1))
#	return best
