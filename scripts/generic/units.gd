class_name Units

const petri_volume : float = 1e12 #picoliters
const cell_volume : float = 8 #picoliters
const water_mass : float = 1 #nanogram per picoliters
const peptide_unit_to_molecules : float = 5000.0

const faraday = 96485.33212
const gas = 8.314462618
const faraday_over_gas = faraday/gas
const RT_F = gas*temperature/faraday
const temperature = 310.15 #37 C

const molecule_count_to_milimolars_in_cell_volume : float = 0.00000021
const membrane_base_input_resistance : float = 0.06

static func reverse_sigmoid(character : int):
	character = character - 65 #translate to 0-15 range
	var normalization = (pow((character-5.0)/15.0, 3.0) + pow(5.0/15.0, 3.0))*3.0
	#normalization ranges between 0 and 1 (for ids 0 and 15), plateus around 5
	#speeds up at the ends, even higher so in the upper end
	return pow(10, normalization)


#reverse_sigmoid + coefficient_to_peptide_amount_unit results these
#A 1.0
#B 1.86685725170609
#C 2.72618645419566
#D 3.31131121482591
#E 3.55722315917079
#F 3.59381366380463 ---- #default for most peptides because plateaus around here
#G 3.63078054770101
#H 3.90041763284635
#I 4.73756907942654
#J 6.91830970918936
#K 12.9154966501488
#L 32.775970160152
#M 120.226443461741
#N 677.814899482905
#O 6245.33236333051
#P 99999.9999999997
#multiply by 5000 to get real-life molecule count
static func coefficient_to_peptide_amount_unit(c : float):
	return pow(c, 5)

static func capital_to_integer(s : int):
	#starts from 0
	return s-65

static func log_map(x : int, in_min := 0, in_max := 14, out_min := 0.1, out_max := 1000) -> float:
	x = clampi(x, in_min, in_max)
	var t = float(x - in_min) / float(in_max - in_min)          # scale input to 0-1
	return out_min * pow(out_max / out_min, t)                # exponential interpolation

#since polymerases also use reverse_sigmoid to determine speed, you actually have
#~256 different expression speeds possible. to display all them, run the following function
#	var rocket : Dictionary
#	for i in range(0, 16):
#		var j = Units.reverse_sigmoid(i+65)
#		for ii in range(0, 16):
#			var jj = Units.reverse_sigmoid(ii+65)
#			var arr = rocket.get_or_add(Units.coefficient_to_peptide_amount_unit(j*jj), [])
#			arr.append(char(i+65) + char(ii+65))
#			
#	var base = rocket.keys()
#	base.sort()
#	for n in base:
#		print(n, " ", rocket[n])

static func to_scientific_notation(x : float, decimals : int = -1):
	if x == 0.0: return "0"
	var exponent = floor(log(absf(x)) / log(10.0))
	var coefficient = x / pow(10.0, exponent)
	if decimals >= 0:
		coefficient = snappedf(coefficient, pow(10, -decimals))
	return str(coefficient) + "x10^" + str(exponent)
