extends Node

var sm : SceneManager
var petri : Petri :
	set(value):
		petri = value
		petri_changed.emit(petri)

signal petri_changed(petri : Petri)

func _ready():
	Substance.generate_basic()
	Nuclein.generate_basic()
