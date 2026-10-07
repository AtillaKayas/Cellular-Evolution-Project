class_name Chemistry

#peptides are calculated from _comp and _nuci

#peptides used for matches() function. this is so that 2 identical Chemistry objects aren't formed.
var _identifier_proteins : Dictionary[Peptide, float]

#numbers useful for fluid
var _mass : float
var _osmolarity : float

#all of these are about protein synthesis or processes.
var _unprocessed : Dictionary[Peptide, float]
var _unsynthesized : Dictionary
#peptides are synthethised only if the binding site that comes after the promoter is active.
var _activated_dna_binding_sites : Dictionary[String, float] #site, speed

#everything Chemistry does, it does for this variable
#every tick, operations do the reactions that are defined in Chemistry
var _operations : Operations

############
#public functions
#############

func _init(cell : Cell, cytosol : Fluid, membrane : Membrane) -> void:
	_operations = Operations.new(cell, cytosol, membrane)

func tick(cytosol : Fluid, membrane : Membrane):
	membrane.clear()
	_operations.tick(cytosol, membrane)
	membrane.tick()


func matches(proteins) -> bool:
	if _identifier_proteins == proteins:
		return true
	return false


func count(components : Dictionary[Substance, float]):
	#measures volume and mass
	_mass = 0
	_osmolarity = 0
	for subs in components:
		var conc : float = components[subs]
		_osmolarity += conc
		_mass += conc*subs.mass

func translation(fluid : Fluid, genome : Genome) :
	#store all possible peptides in _unsynthesized
	#check if some of them are self synthesizing
	#those are removed from _unsynthesized and put into peps and _unprocessed
	
	#if there is anything in _unprocessed, go to _peptide_process
	
	var fpeps : Dictionary[Peptide, float] #active peptides.
	var npeps : Dictionary[Peptide, float] #inactive peptides. they may be inactive but they are synthesized
	_unsynthesized.clear()
	_activated_dna_binding_sites.clear()
	
	#declare all possible peptides and store them in _unsynthesized
	_unsynthesized = genome.get_all_possible_peptides()
	
	#start by seeing if any peptides are self-synthesizing (from the dna template of course)
	for binding_site in _unsynthesized:
		var peptides = _unsynthesized[binding_site]
		_check_self_synthetising_binding_site(binding_site, peptides)
	
	if !_unprocessed.is_empty():
		_peptide_process(fluid, fpeps, npeps)
	
	
	_identifier_proteins.clear()
	_identifier_proteins.merge(fpeps)
	_identifier_proteins.merge(npeps)

	return Proteome.new(fpeps, npeps)

func set_proteins(peps : Dictionary[Peptide, float], fluid : Fluid) :
	_unprocessed.clear()
	_unprocessed.merge(peps)
	_peptide_process(fluid, peps, {})
	_identifier_proteins = peps

func new_operation(name : int, ...args):
	_operations.new_operation(name, args)

func activate_dna_binding_site(site : String, amount : float):
	var existing = _activated_dna_binding_sites.get(site, 0)
	_activated_dna_binding_sites[site] = existing + amount

################
#getters
#################

func get_mass():
	return _mass

############
#private functions
############

#rna-polymerases that bind to their own binding sites in dna may synthesize themselves
func _check_self_synthetising_binding_site(binding_site : String, peptides : Dictionary) -> bool:
	for peptide in peptides:
		for act in peptide.acts:
			if act[0] != Peptide.ACT.RNA_POLYMERASE: continue
			var params = act[1]
			var polymerase_binding_site = params[0]
			var speed = params[1]
			if polymerase_binding_site != binding_site: continue
			#reaching here means this peptide synthethises itself from the DNA
			#loop below adds each peptide into the _unprocessed
			for pep in peptides:
				var amount = peptides[pep]
				_unprocessed[pep] = Units.coefficient_to_peptide_amount_unit(speed*amount)
			_unsynthesized.erase(binding_site)
			return true
	return false

#loops until no more peptide is synthethised
func _peptide_process(fluid : Fluid, fpeps, npeps):
	#go through _unprocessed, make each peptide do activities, then clear _unprocessed
	#check if any new peptide is synthesized
	#if there is, place them in _unprocessed
	#if _unprocessed is not empty, run again
	
	#process peptides
	for pep in _unprocessed:
		var amount = _unprocessed[pep]
		fluid.remove_mass(pep.composition, amount)
		
		var active : bool = pep.activities(self, amount)
		if active:
			fpeps[pep] = amount
		else:
			npeps[pep] = amount
	_unprocessed.clear()
	
	#create new peptides
	for binding_site in _unsynthesized:
		var peptides = _unsynthesized[binding_site]
		var synthesis_speed : float = _activated_dna_binding_sites.get(binding_site, 0.0)
		if synthesis_speed == 0.0: continue
		for peptide in peptides:
			var amount = peptides[peptide]
			_unprocessed[peptide] = Units.coefficient_to_peptide_amount_unit(amount*synthesis_speed)
		_unsynthesized.erase(binding_site)
	
	#new peptide snythesized
	#beware of an infinite loop
	if !_unprocessed.is_empty():
		_peptide_process(fluid, fpeps, npeps)
