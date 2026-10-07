class_name SceneManager extends Control

const START_SCENE = preload("res://scenes/screens/petri.tscn")
const START_UI = preload("res://scenes/ui/petri_overlay.tscn")

enum {DESTROY, KEEP_ACTIVE, KEEP_DISABLED}
enum TRANSITION {NONE, GRADIENT}

@onready var _screens = $Screen
@onready var _uis = $UI
@onready var _transitions = $Transition


var current_screen : Control
var current_ui : Control

var _inactive_screens : Array
var _inactive_uis : Array

func _ready() -> void:
	Global.sm = self
	change_screen(START_SCENE.instantiate())
	change_ui(START_UI.instantiate())

#Changes the current scene with a new one
#Automatically makes the new scene visible
#If it doesn't destroy the old scene and there is an old scene, returns it
#DESTROY -> free the old scene
#KEEP_ACTIVE -> Old scene is sibling of the new scene and is active, but not visible
#KEEP_DISABLED -> Old scene is removed from tree and stored in _inactive_screens
func change_screen(new_screen : Control, manage_old := DESTROY, transition : int = TRANSITION.NONE) -> Control:
	var result : Control
	
	if transition != TRANSITION.NONE:
		_transition(transition, new_screen, manage_old)
		return current_screen
	
	
	if new_screen in _inactive_screens: #These stuff can happen
		_inactive_screens.erase(new_screen)
	
	if current_screen != null:
		_screens.remove_child(current_screen)
		match manage_old:
			KEEP_ACTIVE:
				current_screen.visible = false
				result = current_screen
			KEEP_DISABLED:
				_screens.remove_child(current_screen)
				_inactive_screens.append(current_screen)
				result = current_screen
			_: current_screen.queue_free()
	
	#The reason why this is all the way over here is to stop the new scene's _ready()
	#from firing before we deal with the old scene
	current_screen = new_screen
	_screens.add_child(current_screen)
	current_screen.visible = true #Justin Case
	
	return result

func _transition(type : int, new_screen : Control, manage_old := DESTROY):
	var transition : Transition
	match type:
		_: transition = load("res://scenes/generic/animations/gradient.tscn").instantiate()
	
	transition.manage_old = manage_old
	transition.new_screen = new_screen
	_transitions.add_child(transition)
	transition.enter()

func change_ui(new_ui : Control, manage_old := KEEP_ACTIVE):
	var result : Control
	
	if new_ui in _inactive_uis: #These stuff can happen
		_inactive_uis.erase(new_ui)
	
	if current_ui != null:
		_uis.remove_child(current_ui)
		match manage_old:
			KEEP_ACTIVE:
				current_ui.visible = false
				result = current_ui
			KEEP_DISABLED:
				_uis.remove_child(current_ui)
				_inactive_uis.append(current_ui)
				result = current_ui
			_: current_ui.queue_free()
	
	current_ui = new_ui
	_uis.add_child(current_ui)
	current_ui.visible = true #Justin Case
	
	return result
