class_name Operations
#a class made exclusively for Chemistry to do its operations.
#the reason i made this a seperate class is to not overcrowd Chemistry.
#things the Operations can do are highly correlated with stuff defined in Peptides

enum {PRINT, TRANSPORTER}

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
			TRANSPORTER: _transporter(args)
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
