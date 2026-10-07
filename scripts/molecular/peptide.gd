class_name Peptide


const ACT = {
	RNA_POLYMERASE = "rPOLY",
	PRINT_NAME = "PRINT",
	MEMBRANE_TAG = "MEMB",
	ION_PUMP = "iPUMP",
	TRANSPORTER = "TRANS",
	DEFINE = "DEF"
}

static var DOMAIN = {
	#FUNCTION NAME      #SEQ    #DOMAIN        #Can run with no parameters?
	ACT.RNA_POLYMERASE : ["ICLON", _domain_rna_polymerase, false],
	ACT.PRINT_NAME : ["PLEAD", _domain_dummy, true],
	ACT.MEMBRANE_TAG : ["MEMB", _domain_membrane_tag, true],
	ACT.ION_PUMP : ["IBMB", _domain_ion_pump, false],
	ACT.TRANSPORTER : ["CAB", _domain_transporter, false],
	ACT.DEFINE : ["DEF", _domain_define, false]
}


var sequence : String
var composition : Dictionary[Substance, float]
var is_membrane_bound : bool = false
var acts : Array
var id : int
var definitions : Dictionary[String, Substance]

static var _all : Dictionary[String, Peptide]
static var _last_id : int = -1

func _init(_sequence : String) -> void:
	_all[_sequence] = self
	sequence = _sequence
	id = _last_id + 1
	_last_id = id
	
	_find_composition()
	_find_acts()

func activities(chemistry : Chemistry, amount : float) -> bool:
	#go through acts, return true if acts isn't empty
	#having only membrane tag also returns empty
	if acts.is_empty(): return false
	if acts.size() == 1 and acts[0][0] == ACT.MEMBRANE_TAG: return false
	
	#each act is translated into an operation that will be reported to the Chemistry
	for act in acts:
		var activity_name = act[0]
		var params = act[1].duplicate() #params might be edited later so we duplicate
		match activity_name:
			ACT.RNA_POLYMERASE: _activity_rna_polymerase(chemistry, amount, params)
			ACT.PRINT_NAME: _activity_print_name(chemistry)
			ACT.ION_PUMP: _activity_ion_pump(chemistry, amount, params)
			ACT.TRANSPORTER: _activity_transporter(chemistry, amount, params)
	return true

func find_bottleneck(subs : Dictionary[Substance, float]) -> Array:
	var bottleneck : Substance
	var coefficient : float
	var lowest : float = INF
	for c in composition:
		var amount_provided : float = subs.get(c, 0.0)
		var amount_desired : float = composition[c]
		var ratio = amount_provided/amount_desired
		if ratio < lowest:
			lowest = ratio
			bottleneck = c
			coefficient = amount_desired
	return [bottleneck, coefficient]


#########
#static functions
###########

static func fetch(_sequence : String):
	var result = _all.get(_sequence)
	if result == null:
		return new(_sequence)
	return result


##############
#private_functions
##############


#################
#domains
#################

static func _domain_dummy(_peptide, _sequence, _i) -> Array:
	return []

static func _domain_membrane_tag(_peptide : Peptide, _sequence, _i) -> Array:
	_peptide.is_membrane_bound = true
	return []

static func _domain_rna_polymerase(_peptide, _sequence, i) -> Array:
	var factor : String
	var speed : float
	if i+1 < _sequence.length():
		factor = _sequence[i+1]
	if i+2 < _sequence.length():
		speed = Units.reverse_sigmoid(_sequence.unicode_at(i+2))
	if factor == "":
		return []
	else:
		return [factor, speed]

static func _domain_ion_pump(_peptide, _sequence : String, i):
	#exchanges a substance with an ion. substance pattern is used to define what is passed.
	var ion1 : Substance
	var Kion1 : float
	var maximum_rate : float
	var ion2 : Substance
	var Kion2 : float
	if i+5 >= _sequence.length():
		return []
	
	maximum_rate = pow(1.2, (_sequence.unicode_at(i+1)-58))
	
	ion1 = Substance.fetch_from_pattern(_sequence[i+2] + "ION")
	Kion1 = Units.capital_to_integer(_sequence.unicode_at(i+3))
	ion2 = Substance.fetch_from_pattern(_sequence[i+4] + "ION")
	Kion2 = Units.capital_to_integer(_sequence.unicode_at(i+5))
	
	if ion2 == null or ion1 == null:
		return []
	else:
		return [maximum_rate, ion1, Kion1, ion2, Kion2]

static func _domain_define(peptide, _sequence : String, i):
	#Use this to define a substance pattern into a single character
	#i+1: Character
	#i+2: Length of Pattern
	if _sequence.length()-2 <= i:
		return []
	
	var character = _sequence[i+1]
	
	#ABCD is length 2, EFGH is length 3, IJKL is length 4, MNO is length 5
	var length = ((Units.capital_to_integer(_sequence.unicode_at(i+2)))/4)+2
	length = mini(_sequence.length()-i-3, length) #length trimmed to peptide length
	
	#no sequence left to define
	if length == 0:
		return []
	
	var defined_pattern = _sequence.substr(i+3 , length)
	var subs = Substance.fetch_from_pattern(defined_pattern)
	if subs == null: return []
	
	peptide.definitions[character] = subs
	return []

static func _domain_transporter(_peptide, _sequence : String, i):
	#i+1: Is Pump? (true if O)
	#i+2: Maximum Rate
	#i+3: Substance1
	#i+4: Substance1 Direction and amount
	#i+5: Substance1 Half Saturation Constant
	#i+6: Substance2
	#...
	
	if _sequence.length()-2 <= i:
		return []
	
	var x : float = Units.capital_to_integer(_sequence.unicode_at(i+1))
	var normalization = pow(1.59, x)
	var maximum_rate = normalization
	
	var atp_usage : int = Units.capital_to_integer(_sequence.unicode_at(i+2))/4
	
	#after CABAF, every three letters of the rest of the peptide is a port
	var port_data = _sequence.substr(i+3)
	var ports : Array[Array]
	var division = port_data.length()/3
	for n in division:
		var m = 3*n
		var substance = _peptide._fetch_substance(port_data[m])
		
		#from -3 to +3, skips 0
		var r = floori(Units.capital_to_integer(port_data.unicode_at(m+1))/2.5)
		var direction = r - 3 + floori(r/3)
		
		var half_saturation_constant = \
		Units.log_map(Units.capital_to_integer(port_data.unicode_at(m+2)), 0, 14, 0.2, 80)
		
		if substance == null: continue
		ports.append([substance, direction, half_saturation_constant])
	
	if ports.is_empty() and atp_usage == 0:
		if division*3 != port_data.length():
			#this means that the transporter is actually just a channel
			#channels do not require affinities or directions, therefore
			ports.append([_peptide._fetch_substance(port_data[division*3])])
		else:
			#means there were no viable ports and we don't have anything to work with
			#stuck to the end
			return []
	return [maximum_rate, atp_usage, ports]

###################
#activities
###################
func _activity_rna_polymerase(chemistry : Chemistry, amount : float, params : Array):
	var binding_site = params[0]
	var speed = params[1]
	chemistry.activate_dna_binding_site(binding_site, speed*amount)

func _activity_ion_pump(chemistry : Chemistry, amount : float, params : Array):
	is_membrane_bound = true
	
	#we divide speed by this number because this is the standard expression
	#of a peptide in a given cell (Translation speed F from an A speed polymerase)
	var maximum_rate = params[0]*amount/3.59381366380463
	params[0] = maximum_rate
	chemistry.new_operation(Operations.ION_PUMP, params)

func _activity_transporter(chemistry : Chemistry, amount : float, params : Array):
	is_membrane_bound = true
	
	#we divide speed by this number because this is the standard expression
	#of a peptide in a given cell (Translation speed F from an A speed polymerase)
	var maximum_rate = params[0]*amount/3.59381366380463
	params[0] = maximum_rate
	chemistry.new_operation(Operations.TRANSPORTER, params)

func _activity_print_name(chemistry : Chemistry):
	chemistry.new_operation(Operations.PRINT, sequence)

###########
#other private funcs
##########

func _find_acts():
	acts.clear()
	var word : String = ""
	var i : int = -1
	for n in sequence:
		
		i += 1
		word += n
		if word.length() > 5:
			word = word.right(5)
		
		#this here is a compact way of looking through each function stored in DOMAIN
		#if applicable, the word is reset and a callable is called
		#if the callable returns no parameters it is optional to not add that function or not
		for act in DOMAIN:
			var data = DOMAIN[act]
			if !data[0] in word: continue
			word = ""
			var parameters = data[1].call(self, sequence, i)
			if !(parameters.is_empty() and !data[2]):
				acts.append([act, parameters])
				break

func _find_composition():
	var result : Dictionary[Substance, float]
	for n in sequence:
		var substance := Substance.fetch(n)
		var amount : float = result.get_or_add(substance, 0.0)
		result[substance] = amount + 1
	composition = result

func _to_string() -> String:
	return sequence

func _fetch_substance(definition_character : String) -> Substance:
	var subs = definitions.get(definition_character)
	if subs == null:
		subs = Substance.fetch_from_pattern(definition_character)
	return subs
