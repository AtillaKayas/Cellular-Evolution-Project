extends MarginContainer

enum {STATS, CYTOSOL}

var _selected_cell : Cell
var _selected_tab : int

@onready var _presets = $HBoxContainer/Presets
# Statistics
@onready var _cell_name: LineEdit = $HBoxContainer/TabBar/Stats/GridContainer/CellName/CellName
# Cytosol
@onready var _cytosol_item_list: ItemList = $HBoxContainer/TabBar/Cytosol/ItemList

signal tab_changed(tab : int)
signal substance_data_requested(cell : Cell, subs : Substance)
signal substance_data_unselected



func _ready() -> void:
	Global.petri_changed.connect(_on_petri_changed)
	_on_petri_changed(Global.petri)
	_on_petri_selected_cell_changed(Global.petri.get_selected_cell())


func _on_tab_bar_tab_changed(tab: int) -> void:
	tab_changed.emit(tab)
	_selected_tab = tab
	if _presets == null: return
	if tab == -1:
		_presets.visible = false
	else:
		_presets.visible = true

func _on_petri_changed(petri : Petri):
	petri.selected_cell_changed.connect(_on_petri_selected_cell_changed)

func _on_petri_selected_cell_changed(cell : Cell):
	_selected_cell = cell
	if cell == null: return
	_cell_name.text = cell.name

func _on_cell_name_text_submitted(new_text: String) -> void:
	if Global.petri == null: return
	var cell = Global.petri.get_selected_cell()
	if cell == null: return
	cell.name = new_text
	_on_petri_selected_cell_changed(cell)


func _step() -> void:
	if _selected_cell == null: return
	
	match _selected_tab:
		STATS : _stats_step()
		CYTOSOL: _cytosol_step()
		_: pass

func _stats_step():
	pass

func _cytosol_step():
	var cytosol_data := _selected_cell.get_cytosol_data()
	
	#update items according to cytosol data
	for n in _cytosol_item_list.item_count:
		var subs = _cytosol_item_list.get_item_metadata(n)
		var text = cytosol_data.get(subs)
		
		#the substance shown on the item no longer exist - gotta remove the item
		if !text is String:
			_cytosol_item_list.remove_item(n)
			n -= 1
			continue
		_cytosol_item_list.set_item_text(n, text)
		cytosol_data.erase(subs)
	
	
	#these items weren't in the list - gotta add them
	for subs in cytosol_data:
		var n = _cytosol_item_list.add_item(cytosol_data[subs])
		_cytosol_item_list.set_item_metadata(n, subs)

func _on_cytosol_item_selected(index: int, _at_position: Vector2, _mouse_button_index: int) -> void:
	var subs = _cytosol_item_list.get_item_metadata(index)
	if _cytosol_item_list.is_selected(index):
		substance_data_requested.emit(_selected_cell, subs)
	else:
		substance_data_unselected.emit()
	
	for n in _cytosol_item_list.item_count:
		if n == index: continue
		_cytosol_item_list.deselect(n)
