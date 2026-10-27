class_name Proteome

var _functional_peptides : Dictionary
var _nonfunctional_peptides : Dictionary

func _init(fpeps : Dictionary = {}, npeps : Dictionary = {}):
	_functional_peptides = fpeps
	_nonfunctional_peptides = npeps

static func _sort_dict_values(dict: Dictionary) -> Array:

	var peptides = dict.keys()
	peptides.sort_custom(func(a, b): return a.id < b.id)
	
	return peptides

func get_peptide_amount(peps : Peptide) -> float:
	var amount = _functional_peptides.get(peps)
	if amount == null:
		amount = _nonfunctional_peptides.get(peps)
	if amount == null or !amount is float:
		return 0
	else:
		return amount
