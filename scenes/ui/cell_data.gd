extends MarginContainer

enum {STATS, CYTOSOL, GENOME}

var _selected_cell : Cell
var _selected_tab : int

var _plasmid_triangle = preload("res://sprites/ui/plasmid/triangle.png")
var _plasmid_box = preload("res://sprites/ui/plasmid/box.png")

@onready var _presets = $HBoxContainer/Presets
# Statistics
@onready var _stats : HBoxContainer = $HBoxContainer/TabBar/Stats/GridContainer/Confidence
@onready var _cell_name: LineEdit = $HBoxContainer/TabBar/Stats/GridContainer/CellName/CellName
@onready var _confidence: LineEdit = $HBoxContainer/TabBar/Stats/GridContainer/Confidence/Confidence
@onready var _volume: Label = $HBoxContainer/TabBar/Stats/GridContainer/Volume
# Cytosol
@onready var _cytosol_item_list: ItemList = $HBoxContainer/TabBar/Cytosol/ItemList

# Genome
@onready var _nucleins_list: ItemList = $HBoxContainer/TabBar/Genome/H/V/ItemList
@onready var _nuclein_name : LineEdit = $HBoxContainer/TabBar/Genome/H/V2/H/NucleinName/LineEdit
@onready var _nuclein_sequence : RichTextLabel = $HBoxContainer/TabBar/Genome/H/V2/Panel/M/Sequence
@onready var _font = get_theme_font("normal_font")
@onready var _font_size = get_theme_font_size("normal_font_size")
@onready var _font_width : float = _font.get_string_size("A".repeat(100), HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size).x / 100.0
@onready var _font_height = _font.get_height(_font_size)
@onready var _gene_color = Color(1.0, 1.0, 1.0, 1.0)
@onready var _gene_background_color = Color(0.0, 0.0, 0.0, 1.0)

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
	_presets.visible = tab != -1

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
		GENOME: _genome_step()
		_: pass

func _stats_step():
	if !_confidence.is_editing(): #if it is being edited do not update the text
		_confidence.text = str(snappedf(_selected_cell.confidence, 0.001))
	_volume.text = "Volume: " + str(snappedf(_selected_cell.get_volume(), 0.01)) + " pL"
	

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

func _genome_step():
	var genome_data = _selected_cell.get_genome_data()
	_genome_handle_nuclein_list(genome_data)

func _genome_handle_nuclein_list(_genome_data : Array[Nuclein]):
	var genome_data = _genome_data.duplicate() #we destroy the list later on
	#update items according to genome data
	for n in _nucleins_list.item_count:
		var nuc = _nucleins_list.get_item_metadata(n)
		
		#the item shown on the item no longer exist - gotta remove the item
		if !nuc in genome_data:
			_nucleins_list.remove_item(n)
			n -= 1
			continue
		_nucleins_list.set_item_text(n, nuc.name) #maybe it's changed?
		genome_data.erase(nuc)
	
	#these items weren't in the list - gotta add them
	for nuc in genome_data:
		var n = _nucleins_list.add_item(nuc.name)
		_nucleins_list.set_item_metadata(n, nuc)

func _on_nuclein_selected(_index: int) -> void:
	var selected_arr = _nucleins_list.get_selected_items()
	if selected_arr.is_empty(): return
	var selected = _nucleins_list.get_item_metadata(selected_arr[0]) #there can only be 1 selected
	
	#name
	if !_nuclein_name.is_editing(): #if it has focus doing this messes with the typing
		_nuclein_name.text = selected.name
	
	#sequence
	_nuclein_sequence.text = selected.sequence
	_insert_peptide_data()

func _on_cytosol_item_selected(index: int, _at_position: Vector2, _mouse_button_index: int) -> void:
	var subs = _cytosol_item_list.get_item_metadata(index)
	if _cytosol_item_list.is_selected(index):
		substance_data_requested.emit(_selected_cell, subs)
	else:
		substance_data_unselected.emit()
	
	for n in _cytosol_item_list.item_count:
		if n == index: continue
		_cytosol_item_list.deselect(n)


func _on_line_edit_text_changed(new_text: String) -> void:
	var selected_arr = _nucleins_list.get_selected_items()
	if selected_arr.is_empty(): return
	var selected = _nucleins_list.get_item_metadata(selected_arr[0]) #there can only be 1 selected
	selected.name = new_text


func _on_confidence_text_submitted(new_text: String) -> void:
	if !new_text.is_valid_float(): return
	_selected_cell.confidence = clampf(float(new_text), 0.0, 1.0)
	_stats.grab_focus()

func _insert_peptide_data() -> void:
	var s := _nuclein_sequence.get_parsed_text()
	var line_count = _nuclein_sequence.get_line_count()
	var lines : Dictionary[Array, String] = {}
	
	var genes := {}
	var results = Nuclein.intron_regex.search_all(s)
	for result in results:
		var string = result.get_string()
		var left = Nuclein.PROMOTER.length()
		var true_length = string.length() - (Nuclein.PROMOTER.length() + Nuclein.TERMINATOR.length())
		var intron = string.substr(left + 4, true_length - 4) # we remove promoter
		if intron == "": continue
		var pep_name = Nuclein.seq_to_pep(intron)
		var peptide = Peptide.fetch(pep_name)
		genes[[result.get_start(), result.get_end()-1]] = peptide.get_default_gene_name_base()
	
	for i in line_count:
		var r: Vector2i = _nuclein_sequence.get_line_range(i)  # x = start, y = end
		lines[[r.x, r.y]] = s.substr(r.x, r.y - r.x)
	_nuclein_sequence.clear()
	
	for line_range in lines:
		var line = lines[line_range]
		_nuclein_sequence.append_text(line)
		_nuclein_sequence.newline()
		
		_check_genes_in_line(genes, line_range[0], line_range[1])
		
		_nuclein_sequence.newline()

func _add_boxes(count : int) -> void:
	for i in count:
		#_nuclein_sequence.add_text("=")
		_nuclein_sequence.add_image(_plasmid_box, _font_width, _font_height, _gene_color)

func _fit_label(label : String, width : int) -> String:
	if width <= 0:
		return ""
	if label.length() > width:
		label = label.substr(0, width - 1) + "…" if width >= 2 else ""
	var pad := width - label.length()
	var left := pad / 2
	return " ".repeat(left) + label + " ".repeat(pad - left)

func _add_gene_segment(length : int, finishes : bool, label : String) -> void:
	var body := length - 1 if finishes else length
	var text := _fit_label(label, body)          # padded to exactly `body` characters
	var trimmed := text.strip_edges()
	var lead := text.length() - text.lstrip(" ").length()
	var label_len := trimmed.length()

	# solid blocks before the label
	_nuclein_sequence.push_color(_gene_color)
	_add_boxes(lead)
	_nuclein_sequence.pop()

	# label span: filled cells with the letters cut out in the background color
	if label_len > 0:
		_nuclein_sequence.push_bgcolor(_gene_color)
		_nuclein_sequence.push_color(_gene_background_color)
		_nuclein_sequence.add_text(trimmed)
		_nuclein_sequence.pop()
		_nuclein_sequence.pop()

	# solid blocks after the label
	_nuclein_sequence.push_color(_gene_color)
	_add_boxes(body - lead - label_len)
	if finishes:
		_nuclein_sequence.add_image(_plasmid_triangle, _font_width, _font_height, _gene_color)
	_nuclein_sequence.pop()

func _check_genes_in_line(genes : Dictionary, line_start : int, line_end : int) -> void:
	var cursor := line_start
	for gene_range in genes.keys():
		var g_start : int = gene_range[0]
		var g_end : int = gene_range[1]
		
		if g_end < cursor:
			genes.erase(gene_range)
			continue
		if g_start >= line_end:
			break
		
		var from := maxi(g_start, cursor)
		var to := mini(g_end, line_end - 1)
		var finishes_here := g_end <= line_end - 1
		
		_nuclein_sequence.add_text(" ".repeat(from - cursor))
		var starts_here := g_start >= line_start
		_add_gene_segment(to - from + 1, finishes_here, genes[gene_range] if starts_here else "")
		if finishes_here:
			genes.erase(gene_range)
		
		cursor = to + 1
		if cursor >= line_end:
			break
