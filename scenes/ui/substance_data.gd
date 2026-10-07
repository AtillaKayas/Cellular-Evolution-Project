extends MarginContainer

var _tracked_cell : Cell
var _tracked_substance : Substance
@onready var _rtl : RichTextLabel = $M/V/M/PC/RTL
var total = 110

func _on_cell_data_tab_changed(_tab: int) -> void:
	visible = false

func _on_substance_data_requested(cell: Cell, subs: Substance) -> void:
	_tracked_cell = cell
	_tracked_substance = subs
	visible = true

func _substance_data_unselected() -> void:
	visible = false

func _process(_delta: float) -> void:
	if !visible: return
	if _tracked_cell == null: return
	if _tracked_substance == null: return
	if _rtl == null: return
	total += _delta
	if total > 0.5:
		total = 0
	else:
		return
	
	_rtl.clear()
	
	if _tracked_substance.nick == "":
		_rtl.add_text("Name: {0}".format([_tracked_substance.name]))
	else:
		_rtl.add_text("Display Name: {0}\nName: {1}".format([_tracked_substance.nick, _tracked_substance.name]))
	_rtl.newline()
	_rtl.add_text("Charge: {0}, Mass: {1}".format([_tracked_substance.charge, _tracked_substance.mass]))
	_rtl.newline()
	_rtl.add_text("Pattern: {0}".format([_tracked_substance.pattern]))
	_rtl.newline()
	_rtl.newline()
	_rtl.add_text("Tracked Cell: {0}".format([_tracked_cell.name]))
	
	var intracellular = _tracked_cell.get_cytosol_substance_concentration(_tracked_substance)
	var extracellular = _tracked_cell.get_extracellular_substance_concentration(_tracked_substance)
	if extracellular == "0.0 mM":
		_rtl.newline()
		_rtl.add_text("Amount: {0}".format([intracellular]))
	else:
		_rtl.newline()
		_rtl.add_text("Intracellular: {0}".format([intracellular]))
		_rtl.newline()
		_rtl.add_text("Extracellular: {0}".format([extracellular]))
	
	var flux_report = _tracked_cell.get_flux_report(_tracked_substance)
	var flux = Units.to_scientific_notation(flux_report[0], 1) + " fmol/t"
	if flux_report[1] == 0.0:
		_rtl.newline()
		_rtl.add_text("Net Flux: {0}".format([flux]))
	else:
		var nernst = str(snappedf(flux_report[1]*1000, 0.1)) + " mV"
		_rtl.newline()
		_rtl.add_text("Nernst Potential: {0}".format([nernst]))
		_rtl.newline()
		var mPot = str(snappedf(_tracked_cell.get_membrane_potential()*1000, 0.1)) + " mV"
		_rtl.add_text("Membrane Potential: {0}".format([mPot]))
		_rtl.newline()
		_rtl.add_text("Net Flux: {0}".format([flux]))
	
	if flux_report[2] != 0.0:
		var active_flux = Units.to_scientific_notation(flux_report[2], 1)
		var passive_flux = Units.to_scientific_notation(flux_report[3], 1)
		_rtl.newline()
		_rtl.add_text("Active Flux: {0}".format([active_flux]))
		_rtl.newline()
		_rtl.add_text("Passive Flux: {0}".format([passive_flux]))
	
	_rtl.newline()
	_rtl.add_text("Permeability: {0}".format([_tracked_cell.get_membrane_permeability(_tracked_substance)]))
