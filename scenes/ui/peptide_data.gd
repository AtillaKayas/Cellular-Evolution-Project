extends MarginContainer

var _tracked_cell : Cell
var _tracked_peps : Peptide
@onready var _rtl : RichTextLabel = $M/V/M/PC/RTL
var total = 110

func _on_cell_data_tab_changed(_tab: int) -> void:
	visible = false

func _on_cell_data_peptide_data_requested(cell: Cell, peptide: Peptide) -> void:
	_tracked_cell = cell
	_tracked_peps = peptide
	visible = true

func _substance_data_unselected() -> void:
	visible = false

func _process(_delta: float) -> void:
	if !visible: return
	if _tracked_cell == null: return
	if _tracked_peps == null: return
	if _rtl == null: return
	total += _delta
	if total > 0.5:
		total = 0
	else:
		return
	
	_rtl.clear()
	
	_rtl.add_text("Sequence: {0}".format([_tracked_peps.sequence]))
	_rtl.newline()
	
	if _tracked_peps.nick == "":
		_rtl.add_text("Name: {0} (Same as gene)".format([_tracked_peps.get_gene_name()]))
	else:
		_rtl.add_text("Name: {0}\nGene Name: {1}".format([_tracked_peps.nick, _tracked_peps.get_gene_name()]))
	_rtl.newline()
	_rtl.add_text("Charge: {0}, Mass: {1}".format([_tracked_peps.charge, _tracked_peps.mass]))
	_rtl.newline()
	_rtl.newline()
	
	var peptide_amount = snappedf(_tracked_cell.get_peptide_amount(_tracked_peps), 0.1)
	var _peptide_molecules = peptide_amount*Units.peptide_unit_to_molecules
	var peptide_molarity = snappedf(peptide_amount*8/_tracked_cell.get_volume(), 0.1)
	_rtl.add_text("Amount: {0}\nMolarity: {1} nM".format([peptide_amount, peptide_molarity]))
	_rtl.newline()
	_rtl.newline()
	
	_rtl.add_text("Tracked Cell: {0}".format([_tracked_cell.name]))
	_rtl.newline()
	_rtl.newline()
	_rtl.add_text(_tracked_peps.get_descriptions(peptide_amount))
	
