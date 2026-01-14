class_name SelectionManager
extends Node

## Manages character selection state
## Supports single selection with automatic deselection of previous selection

signal selection_changed(character: CharacterBody3D)

var _selected_character: CharacterBody3D = null


func get_selected() -> CharacterBody3D:
	return _selected_character


func select(character: CharacterBody3D) -> void:
	if _selected_character == character:
		return

	# Deselect previous
	if _selected_character:
		_selected_character.set_selected(false)

	# Select new
	_selected_character = character
	if _selected_character:
		_selected_character.set_selected(true)

	selection_changed.emit(_selected_character)


func deselect() -> void:
	select(null)


func is_selected(character: CharacterBody3D) -> bool:
	return _selected_character == character
