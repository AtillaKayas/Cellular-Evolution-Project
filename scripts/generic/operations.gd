class_name Operations
#a class made exclusively for Chemistry to do its operations.
#the reason i made this a seperate class is to not overcrowd Chemistry.
#things the Operations can do are highly correlated with stuff defined in Peptides

enum {PRINT, TRANSPORTER, REACTION}

const REACTIONS_SPEED := 1e-3

var _data : Array
var _cell : Cell
var _cytosol : Fluid
var _membrane : Membrane

func _init(cell : Cell, cytosol : Fluid, membrane : Membrane):
	_cell = cell
	_cytosol = cytosol
	_membrane = membrane
	

func new_operation(name : int, args : Array):
	#some operations are one-off, they only apply at the start.
	#if it is not one of them, we append them in _data
	match name:
		TRANSPORTER: _transporter(args)
		_: _data.append([name, args])

func tick(cytosol : Fluid, membrane : Membrane):
	for op in _data:
		if !op is Array: continue
		if op.is_empty(): continue
		if !op[0] is int: continue
		var args : Array
		if op.size() > 1:
			args = op[1]
		match op[0]:
			PRINT: _print(args)
			REACTION: _reaction(args)
			_: _dummy(args)

func _print(args : Array):
	prints(args)

func _transporter(args : Array):
	var maximum_rate = args[0][0]
	var atp_usage = args[0][1]
	var ports = args[0][2]
	if atp_usage == 0 and ports.size() == 1:
		#is just a plain channel, not a pump or contransporter
		var subs = ports[0][0]
		_membrane.increase_permeability(subs, maximum_rate)
		return
	#if code reaches here it is a carrier that includes pumps and co-transporters
	_membrane.add_carrier(maximum_rate, atp_usage, ports)
	
func _dummy(args : Array):
	printerr("ERROR: Unknown operation. - ", args)

func _reaction(args : Array):
	
	var maximum_rate = args[0][0]
	var reactants = args[0][1]
	var products = args[0][2]
	var dG0 = args[0][3]
	
	var forward_activation := 1.0
	var log_quotient := 0.0          # ln([P] / prod([R]^n)),
	
	for r in reactants:
		var subs : Substance = r
		var amount : int = reactants[r][0]
		var K : float = reactants[r][1]

		var C : float = maxf(_cytosol.get_concentration(subs), 1e-12)
		forward_activation *= pow(C / (K + C), amount)
		log_quotient -= amount * log(C / 1000) # to molar,
	
	var reverse_activation := 1.0
	
	for p in products:
		var subs : Substance = p
		var amount : int = products[p][0]
		var K : float = products[p][1]
		
		var C : float = maxf(_cytosol.get_concentration(subs), 1e-12)
		reverse_activation *= pow(C / (K + C), amount)
		log_quotient += amount * log(C / 1000) # to molar

	# standard delta G (kJ/mol) -> volts, as in _carry
	var net_energy : float = dG0 * 1000.0 / Units.faraday + Units.RT_F * log_quotient

	var driving := maxf(1.0 - exp(minf(net_energy / Units.RT_F, 20.0)), -1.0)

	var activation := forward_activation if driving > 0.0 else reverse_activation
	var reaction_rate : float = maximum_rate * activation * driving * (1.0/Petri.tps) * REACTIONS_SPEED
	
	var consumed : Dictionary = reactants if reaction_rate > 0.0 else products
	var limit := INF
	for s in consumed:
		limit = minf(limit, _cytosol.get_concentration(s) / consumed[s][0])
	reaction_rate = signf(reaction_rate) * minf(absf(reaction_rate), limit)
	
	for r in reactants:
		_cytosol.add_substance(r, -reaction_rate * reactants[r][0])
	for p in products:
		_cytosol.add_substance(p, reaction_rate * products[p][0])
