class_name Genome

var _nucleins : Dictionary[Nuclein, int]

func _init(nucleins : Dictionary[Nuclein, int]):
	_nucleins = nucleins


func get_all_possible_peptides() -> Dictionary:
	# returns {
	# 	binding_site (String) : {
	#		protein_a (Peptide) : 1.0,
	#		protein_b (Peptide) : 2.0,
	#		...
	#	},
	#	...
	#}
	
	var result : Dictionary
	for n in _nucleins:
		for intron in n.introns:
			var product = Nuclein.seq_to_pep(intron)
			var binding_site = product[0]
			var speed = Units.reverse_sigmoid(product.unicode_at(1))
			product = product.substr(2, product.length()-2) #we trim the promoter
			if product == "": continue
			
			var peptide = Peptide.fetch(product)
			
			var peptides = result.get(binding_site)
			if !peptides is Dictionary:
				peptides = {}
				result[binding_site] = peptides
			
			if peptide in peptides:
				peptides[peptide] += speed
			else:
				peptides[peptide] = speed

	return result
