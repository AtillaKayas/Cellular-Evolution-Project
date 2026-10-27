class_name Peptide

static var DEFAULT_AMINOS : PackedStringArray = ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q"]
static var AMINO_POOL : Array[Substance]

const ACT = {
	RNA_POLYMERASE = "rPOLY",
	PRINT_NAME = "PRINT",
	MEMBRANE_TAG = "MEMB",
	TRANSPORTER = "TRANS",
	DEFINE = "DEF",
	COMBINE = "ADD",
	GLYCOLYSIS = "GLYSIS",
	KINASE = "KNASE",
	CYCLIN = "CYCLE",
	AQUAPORIN = "AQP",
	AA_TRANSPORTER = "aTRANS"
}

static var DOMAIN = {
	#FUNCTION NAME      #SEQ    #DOMAIN        #Can run w/o params? #DESCRIPTION
	ACT.RNA_POLYMERASE : ["ICLON", _domain_rna_polymerase, false, _activity_rna_polymerase, _desc_rna_polymerase],
	ACT.PRINT_NAME : ["PLEAD", _domain_print, true, _activity_print_name],
	ACT.MEMBRANE_TAG : ["MEMB", _domain_membrane_tag, true, _activity_dummy],
	ACT.TRANSPORTER : ["CAB", _domain_transporter, false, _activity_transporter, _desc_transporter],
	ACT.DEFINE : ["DEF", _domain_define, false, _activity_dummy],
	ACT.COMBINE : ["ADD", _domain_combine, false, _activity_combine],
	ACT.GLYCOLYSIS : ["GLIE", _domain_gylcolysis, false, _activity_glycolysis, _desc_glycolysis],
	ACT.KINASE : ["KINAE", _domain_kinase, false, _activity_kinase],
	ACT.CYCLIN : ["CCND", _domain_cycle, false, _activity_cycle],
	ACT.AQUAPORIN : ["FLOOD", _domain_aquaporin, false, _activity_aquaporin],
	ACT.AA_TRANSPORTER: ["ACIM", _domain_aa_transporter, false, _activity_aa_transporter],
}

var nick : String
var sequence : String
var composition : Dictionary[Substance, float]
var is_membrane_bound : bool = false
var acts : Array
var id : int
var definitions : Dictionary[String, Substance]

var charge : int
var mass : float

static var _gene_table : Dictionary
var _default_gene_name_base : String
var _activity_id : int

static var _all : Dictionary[String, Peptide]
static var _last_id : int = -1

func _init(_sequence : String) -> void:
	_all[_sequence] = self
	sequence = _sequence
	id = _last_id + 1
	_last_id = id
	
	_find_composition()
	_find_acts()
	_register_gene()

func activities(chemistry : Chemistry, amount : float) -> bool:
	#go through acts, return true if acts isn't empty
	#having only membrane tag also returns empty
	if acts.is_empty(): return false
	if acts.size() == 1 and acts[0][0] == ACT.MEMBRANE_TAG: return false
	
	#each act is translated into an operation that will be reported to the Chemistry
	for act in acts:
		var activity_name = act[0]
		var params = act[1].duplicate() #params might be edited later so we duplicate
		var activity_function = DOMAIN[activity_name][3]
		activity_function.call(self, chemistry, amount, params)
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

func get_gene_name() -> String:
	#this right here is a standardized way of generating gene names
	var cat = _gene_table[_default_gene_name_base]
	var name := _default_gene_name_base
	if cat["activities"].size() > 1:
		name += " " + Units.to_alpha(cat["activities"].keys().find(_activity_id))
	var seqs = cat["activities"][_activity_id]["sequences"]
	if seqs.size() > 1:
		name += str(seqs[sequence] + 1)
	return name

func get_name() -> String:
	if nick != "": return nick
	
	#just return the gene name if it was not nicked
	return get_gene_name()

func get_descriptions(amount : float) -> String:
	var result : String = ""
	for act in acts:
		var activity_name = act[0]
		var params = act[1]
		result += activity_name + "\n"
		var act_data = DOMAIN.get(activity_name)
		if act_data == null: continue
		if !act_data is Array: continue
		if act_data.size() < 5: continue
		var desc_function = act_data[4]
		if !desc_function is Callable: continue
		result += desc_function.call(amount, params) + "\n\n"
	return result

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

func _register_gene():
	if acts.is_empty(): _default_gene_name_base = "d"
	var cat = _gene_table.get_or_add(_default_gene_name_base, {"activities": {}})
	var variations = cat["activities"].get_or_add(_activity_id, {"sequences": {}})
	if not variations["sequences"].has(sequence):
		variations["sequences"][sequence] = variations["sequences"].size()

#################
#domains
#################

static func _domain_dummy(_peptide, _sequence, _i) -> Array:
	return []

static func _domain_print(_peptide, _sequence, _i) -> Array:
	_peptide._default_gene_name_base += ACT.PRINT_NAME.substr(0, 2)
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
		speed = get_promoter_speed(_sequence.unicode_at(i+2))
	if factor == "":
		return []
	else:
		_peptide._default_gene_name_base += ACT.RNA_POLYMERASE.substr(0, 2)
		return [factor, speed]

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
	#i+1: Maximum Rate
	#i+2: ATP Usage --nonexistent in a regular _domain_combine as it is calculated there
	#i+3: Substance1
	#i+4: Substance1 Direction and amount
	#i+5: Substance1 Half Saturation Constant (Km)
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
		
		#different from a standard _domain_define, we don't need high numbers.
		#from -3 to +3, skips 0
		var r = floori(Units.capital_to_integer(port_data.unicode_at(m+1))/2.5)
		var direction = r - 3 + floori(r/3)
		
		var half_saturation_constant = \
		Units.log_map(Units.capital_to_integer(port_data.unicode_at(m+2)), 0, 14, 0.2, 80)
		
		if substance == null: continue
		ports.append([substance, direction, half_saturation_constant])
		_peptide._default_gene_name_base += str(substance).substr(0, 2)
	
	#this part is different from _domain_combine. you can define channels without all that jizz.
	if ports.is_empty() and atp_usage == 0:
		if division*3 != port_data.length():
			#this means that the transporter is actually just a channel
			#channels do not require affinities or directions, therefore we can append it this way
			var substance = _peptide._fetch_substance(port_data[division*3])
			ports.append([substance])
			_peptide._default_gene_name_base += str(substance).substr(0, 2)
		else:
			#means there were no viable ports and we don't have anything to work with
			#stuck to the end
			return []
	
	
	
	_peptide._default_gene_name_base += ACT.TRANSPORTER.substr(0, 2)
	
	return [maximum_rate, atp_usage, ports]

static func _domain_combine(_peptide, _sequence : String, i):
	#i+1: Maximum Rate
	#i+2: Product Half Saturation Constant
	#i+3: Reactant1
	#i+4: Reactant1 amount
	#i+5: Reactant1 Half Saturation Constant (Km)
	#i+6: Reactant2
	#i+7: Reactant2 amount
	#...
	
	if _sequence.length()-7 <= i:
		return []
	
	var x : float = Units.capital_to_integer(_sequence.unicode_at(i+1))
	var normalization = pow(1.59, x)
	var maximum_rate = normalization
	
	var product_half_saturation_constant = \
		Units.log_map(Units.capital_to_integer(_sequence.unicode_at(i+2)), 0, 14, 0.2, 80)
	
	#var atp_usage : int = Units.capital_to_integer(_sequence.unicode_at(i+2))
	
	var product_name := ""
	var total_bond_count : int = -1
	
	#after ADDAA, every three letters of the rest of the peptide is a reactant
	var reactant_data = _sequence.substr(i+3)
	var reactants : Dictionary[Substance, Array]
	var division = reactant_data.length()/3
	for n in division:
		var m = 3*n
		var substance = _peptide._fetch_substance(reactant_data[m])
		
		var half_saturation_constant = \
		Units.log_map(Units.capital_to_integer(reactant_data.unicode_at(m+2)), 0, 14, 0.2, 80)
		
		if substance == null: continue
		var amount = Units.capital_to_integer(reactant_data.unicode_at(m+1))+1
		_add_reaction_term(reactants, substance, amount, half_saturation_constant)
		
		for a in amount:
			product_name += substance.name
		total_bond_count += amount
		
	
	if !(reactants.size() > 1 or (reactants.size() == 1 && total_bond_count > 0)):
		return []
	
	var product = Substance.fetch(product_name)
	if product == null:
		return []
	
	var products : Dictionary[Substance, Array]
	_add_reaction_term(products, product, 1, product_half_saturation_constant)
	
	var delta_g = _calculate_delta_g(products, reactants)
	
	var water_formation_energy = total_bond_count*(-237) #water formation energy is around -237
	
	var atp_usage := 0
	if delta_g > 0:
		atp_usage = ceili(delta_g/Units.atp_energy) #intrinsic to ATP hydrolysis
	
	var dG0_total = delta_g + water_formation_energy + atp_usage * (-30.5)
	
	if atp_usage != 0:
		_add_reaction_term(reactants, Substance.fetch("appp"), atp_usage, 0.5)
		_add_reaction_term(products, Substance.fetch("app"), atp_usage, 0.5)
		_add_reaction_term(products, Substance.fetch("p"), atp_usage, 1.0)
	
	_remove_intermediary(products, reactants)
	_peptide._default_gene_name_base += ACT.COMBINE.substr(0, 2)
	
	return [maximum_rate, reactants, products, dG0_total]

static func _domain_gylcolysis(_peptide, _sequence : String, i):
	#i+1: Maximum Rate
	
	if _sequence.length()-1 <= i:
		return []
	
	var x : float = Units.capital_to_integer(_sequence.unicode_at(i+1))
	var normalization = pow(1.59, x)
	var maximum_rate = normalization
	
	var g6p = Substance.fetch("gp")
	var pyruvate = Substance.fetch("h")
	var atp = Substance.fetch("appp")
	var adp = Substance.fetch("app")
	var p = Substance.fetch("p")
	
	var reactants : Dictionary
	var products : Dictionary
	
	_add_reaction_term(reactants, g6p, 1, 0.5)
	_add_reaction_term(products, pyruvate, 2, 0.5)
	
	var delta_g = _calculate_delta_g(products, reactants)
	
	delta_g += -258.88 #include 2NAD -> 2NADH
	
	_add_reaction_term(reactants, adp, 3, 0.5)
	_add_reaction_term(reactants, p, 3, 0.5)
	_add_reaction_term(products, atp, 3, 0.5)
	
	const atp_generated = 3 #this is how it is done in a real cell
	var dG0_total = delta_g + atp_generated * (30.5)
	
	_peptide._default_gene_name_base += ACT.GLYCOLYSIS.substr(0, 2)
	
	return [maximum_rate, reactants, products, dG0_total]

static func _domain_kinase(_peptide, _sequence : String, i):
	#i+1: Maximum Rate
	#i+2: Substance
	#i+3: Half-Saturation Constant
	
	if _sequence.length()-2 <= i:
		return []
	
	var x : float = Units.capital_to_integer(_sequence.unicode_at(i+1))
	var normalization = pow(1.59, x)
	var maximum_rate = normalization
	
	var reactant = _peptide._fetch_substance(_sequence[i+2])
	if reactant == null: return []
	
	var product_name : String = reactant.name + "p"
	var product = Substance.fetch(product_name)
	if product == null: return []
	
	var half_saturation_constant = \
	Units.log_map(Units.capital_to_integer(_sequence.unicode_at(i+1)), 0, 14, 0.2, 80)

	var reactants : Dictionary
	var products : Dictionary
	
	_add_reaction_term(reactants, reactant, 1, half_saturation_constant)
	_add_reaction_term(products, product, 1, 0.5)
	var atp = Substance.fetch("appp")
	var adp = Substance.fetch("app")
	
	_add_reaction_term(reactants, atp, 1, 0.5)
	_add_reaction_term(products, adp, 1, 0.5)
	
	var dG0_total = _calculate_delta_g(products, reactants)
	#we don't add atp or water here as this reaction accounts for them already
	
	_peptide._default_gene_name_base += ACT.KINASE.substr(0, 2)
	
	return [maximum_rate, reactants, products, dG0_total]

static func _domain_cycle(_peptide, _sequence : String, i):
	if _sequence.length()-1 <= i:
		return []
	
	var rate = (float(Units.capital_to_integer(_sequence.unicode_at(i+1)))-7.5)*0.000001
	
	_peptide._default_gene_name_base += ACT.CYCLIN.substr(0, 2)
	
	return [rate]

static func _domain_aquaporin(_peptide, _sequence : String, i):
	if _sequence.length()-1 <= i:
		return []
	
	var rate = \
	Units.log_map(Units.capital_to_integer(_sequence.unicode_at(i+1)), 0, 15, 0.1, 1)
	
	_peptide._default_gene_name_base += ACT.AQUAPORIN.substr(0, 2)
	
	
	return [rate]

static func _domain_aa_transporter(_peptide, _sequence : String, i):
	#i+1: Maximum Rate
	#i+2: Substance to symportt with
	#i+3: Substance1 Direction and amount
	#i+4: Substance1 Half Saturation Constant (Km)
	#i+5: Amino Acid Half Saturation Constant (Km)
	
	if _sequence.length()-5 <= i:
		return []
	
	var x : float = Units.capital_to_integer(_sequence.unicode_at(i+1))
	var normalization = pow(1.59, x)
	var maximum_rate = normalization
	
	var substance = _peptide._fetch_substance(_sequence[i+2])
	if substance == null:
		return []
	var r = floori(Units.capital_to_integer(_sequence.unicode_at(i+3))/2.5)
	var direction = r - 3 + floori(r/3)
	var K_subs = \
	Units.log_map(Units.capital_to_integer(_sequence.unicode_at(i+4)), 0, 14, 0.2, 80)
	
	var K_amino = \
	Units.log_map(Units.capital_to_integer(_sequence.unicode_at(i+5)), 0, 14, 0.2, 80)
	
	_peptide._default_gene_name_base += ACT.AA_TRANSPORTER.substr(0, 2)
	
	return [maximum_rate, substance, direction, K_subs, K_amino]

###################
#activities
###################
static func _activity_dummy(_p, _c, _a, _params):
	return

static func _activity_rna_polymerase(_peptide : Peptide, chemistry : Chemistry, amount : float, params : Array):
	var binding_site = params[0]
	var speed = params[1]
	chemistry.activate_dna_binding_site(binding_site, speed*amount)

static func _activity_transporter(peptide : Peptide, chemistry : Chemistry, amount : float, params : Array):
	peptide.is_membrane_bound = true
	
	#we divide speed by this number because this is the standard expression
	#of a peptide in a given cell (Translation speed F from an A speed polymerase)
	var maximum_rate = params[0]*amount/3.59381366380463
	params[0] = maximum_rate
	chemistry.new_operation(Operations.TRANSPORTER, params)
	
	var atp_usage = params[1]
	if atp_usage > 0:
		var atp_degradation_params = [
			maximum_rate,
			{
				Substance.fetch("appp") : [
					atp_usage,
					0.5
				]
			},
			{
				Substance.fetch("app") : [
					atp_usage,
					0.5
				],
				Substance.fetch("p") : [
					atp_usage,
					1
				]
			},
			-30.5
		]
		chemistry.new_operation(Operations.REACTION, atp_degradation_params)
	

static func _activity_combine(_peptide : Peptide, chemistry : Chemistry, amount : float, params : Array):

	#we divide speed by this number because this is the standard expression
	#of a peptide in a given cell (Translation speed F from an A speed polymerase)
	var maximum_rate = params[0]*amount/3.59381366380463
	params[0] = maximum_rate
	chemistry.new_operation(Operations.REACTION, params)


static func _activity_glycolysis(_peptide : Peptide, chemistry : Chemistry, amount : float, params : Array):

	#we divide speed by this number because this is the standard expression
	#of a peptide in a given cell (Translation speed F from an A speed polymerase)
	var maximum_rate = params[0]*amount/3.59381366380463
	params[0] = maximum_rate
	chemistry.new_operation(Operations.REACTION, params)


static func _activity_cycle(_p, chemistry : Chemistry, amount : float, params : Array):
	var rate = params[0]*amount/3.59381366380463
	params[0] = rate
	chemistry.new_operation(Operations.CYCLE, params)

static func _activity_aquaporin(_p, chemistry : Chemistry, amount : float, params : Array):
	var rate = params[0]*amount/3.59381366380463/2
	params[0] = rate
	chemistry.new_operation(Operations.AQUAPORIN, params)

static func _activity_kinase(_p, chemistry : Chemistry, amount : float, params : Array):

	#we divide speed by this number because this is the standard expression
	#of a peptide in a given cell (Translation speed F from an A speed polymerase)
	var maximum_rate = params[0]*amount/3.59381366380463
	params[0] = maximum_rate
	chemistry.new_operation(Operations.REACTION, params)

static func _activity_print_name(peptide : Peptide, chemistry : Chemistry, amount : float, params : Array):
	chemistry.new_operation(Operations.PRINT, peptide.sequence)

static func _activity_aa_transporter(peptide : Peptide, chemistry : Chemistry, amount : float, params : Array):
	peptide.is_membrane_bound = true
	
	#we divide speed by this number because this is the standard expression
	#of a peptide in a given cell (Translation speed F from an A speed polymerase)
	var maximum_rate = params[0]*amount/3.59381366380463
	params[0] = maximum_rate
	chemistry.new_operation(Operations.AA_TRANSPORTER, params)

#############
##descriptions
##############

static func _desc_rna_polymerase(amount : float, params : Array) -> String:
	var binding_site = params[0]
	var speed = params[1]
	var sxa = params[1]*amount
	
	return "Binding Site: {0}\nSpeed: {1}\n(Speed*Amount): {2}".format([
		binding_site, speed, sxa
	])

static func _desc_transporter(amount : float, params : Array) -> String:
	var maximum_rate = snappedf(params[0]*amount, 0.1)
	var atp_usage = params[1]
	var ports = params[2]

	var port_data : String = ""
	
	var i = 0
	for port in ports:
		i += 1
		var substance_name = port[0]
		if port.size() > 1:
			var stoi = port[1]
			var km = snappedf(port[2], 0.1)
			port_data += "Substance{0}: {1}\nStoichiometry: {2}, Km: {3}\n\n".format([
				i, substance_name, stoi, km
			])
		else:
			port_data += "Channel: {0}".format([
				substance_name
			])
	
	return "Total Max Rate: {0}\n ATP Usage: {1}\n\nPorts;\n{2}".format([
		maximum_rate, atp_usage, port_data
	])

static func _desc_glycolysis(amount : float, params : Array) -> String:
	var maximum_rate = snappedf(params[0], 0.01)
	var total_max_rate = snappedf(maximum_rate*amount, 0.01)
	
	return "Max Rate: {0}\nTotal Max Rate: {1}".format([
		maximum_rate, total_max_rate,
	])

###########
#other private funcs
##########

static func get_promoter_speed(character : int):
	return Units.reverse_sigmoid(character)

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
	_activity_id = hash(acts)

func _find_composition():
	var result : Dictionary[Substance, float]
	for n in sequence:
		var substance := Substance.fetch(n)
		var amount : float = result.get_or_add(substance, 0.0)
		result[substance] = amount + 1
		charge += substance.charge
		mass += substance.mass
	composition = result

func _to_string() -> String:
	return sequence

func _fetch_substance(definition_character : String) -> Substance:
	var subs = definitions.get(definition_character)
	if subs == null:
		subs = Substance.fetch_from_pattern(definition_character)
	return subs

static func _add_reaction_term(dict : Dictionary, subs : Substance, amount : float, k : float):
	var data : Array = dict.get_or_add(subs, [0, k])
	data[0] += amount
	data[1] = (data[1]+k)/2

static func _calculate_delta_g(products : Dictionary, reactants : Dictionary):
	var delta_g = 0
	for n in products:
		delta_g += n.formation_energy * products[n][0]
	for n in reactants:
		delta_g -= n.formation_energy * reactants[n][0]
	
	return delta_g

static func _remove_intermediary(products : Dictionary, reactants : Dictionary):
	#this is to remove any substance that only exists as an intermediary
	#eg: in the reaction Adenosine + 2Pi + 2 ATP -> 3ATP + 2Pi, 2Pi's are not actually necessary
	#doing this both saves calculation and energy for the cell
	for s in reactants.keys():
		if products.has(s):
			var net : int = int(reactants[s][0] - products[s][0])
			if net > 0:
				reactants[s][0] = net
				products.erase(s)
			elif net < 0:
				products[s][0] = -net
				reactants.erase(s)
			else:
				reactants.erase(s)
				products.erase(s)
