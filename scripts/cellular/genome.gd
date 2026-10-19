class_name Genome

var _nucleins : Array

func _init(nucleins : Array):
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

func get_nucleins():
	return _nucleins.duplicate()

func replicate() -> Genome:
	
	var result : Array[Nuclein]
	for n in _nucleins:
		var original_mutated : bool = false
		var single_base_mutation : int = _mutation_amount(2e-4*n.sequence.length())
		var amplification : int = _mutation_amount(1e-5*n.sequence.length())
		var large_deletion : int = _mutation_amount(1e-5*n.sequence.length())
		var polyploidy : int = _mutation_amount(1e-6*n.sequence.length())
		var plasmid_deletion : bool = randf_range(0, 1) < minf(0.01, 2e-6*n.sequence.length())
		
		if plasmid_deletion:
			continue
		var alter : String = n.sequence
		
		for m in single_base_mutation:
			if alter.is_empty(): break
			var working = alter
			var pos = randi_range(0, working.length()-1)
			var on_self = false#randi_range(0, 3) == 0  #lets not do this just yet
			
			
			match randi_range(0, 2):
				0: #substitution
					working[pos] = Nuclein.DEFAULT_BASES.pick_random()
				1: #insertion
					working = working.insert(pos, Nuclein.DEFAULT_BASES.pick_random())
				_: #deletion
					working = working.erase(pos, 1)
			if on_self:
				n.sequence = working
				original_mutated = true
			else:
				alter = working
		for m in amplification:
			if alter.is_empty(): break
			var working = alter
			var pos = randi_range(0, working.length())
			var scale = randi_range(1, 100)
			var on_self = false#randi_range(0, 3) == 0  #lets not do this just yet
			working = working.insert(pos, working.substr(pos, scale))
			if on_self:
				n.sequence = working
				original_mutated = true
			else:
				alter = working
		for m in large_deletion:
			if alter.is_empty(): break
			var working = alter
			var pos = randi_range(0, working.length())
			var scale = randi_range(1, 100)
			var on_self = false#randi_range(0, 3) == 0  #lets not do this just yet
			working = working.substr(0, pos) + working.substr(scale + pos)
			if on_self:
				n.sequence = working
				original_mutated = true
			else:
				alter = working
		if original_mutated:
			n.recalculate_peptides()
		for p in polyploidy + 1:
			if alter.is_empty(): break
			result.append(Nuclein.new(n.name, alter))
	return Genome.new(result)

func _mutation_amount(chance_per_base : float) -> int:
	#yeah, we don't want things to occur too often
	chance_per_base = clampf(chance_per_base, 0, 0.5)
	var result = 0
	var is_true = randf_range(0, 1) < chance_per_base
	if is_true:
		result += 1
		result += _mutation_amount(chance_per_base)
	return result
