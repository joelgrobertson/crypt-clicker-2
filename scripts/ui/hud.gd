extends Control
## In-game HUD — shows wave info, kills, timer, and door health.
## Kept minimal and retro-styled to match PS1 aesthetic.

@onready var wave_label: Label = $MarginContainer/VBoxContainer/WaveLabel
@onready var kills_label: Label = $MarginContainer/VBoxContainer/KillsLabel
@onready var timer_label: Label = $MarginContainer/VBoxContainer/TimerLabel
@onready var door_label: Label = $MarginContainer/RightColumn/DoorLabel

func _ready() -> void:
	# Initial display
	update_display(0, 0, 0.0, 20)

func update_display(wave: int, kills: int, timer: float, door_hp: int) -> void:
	if wave_label:
		wave_label.text = "WAVE %d" % wave
	if kills_label:
		kills_label.text = "KILLS: %d" % kills
	if timer_label:
		var minutes := int(timer) / 60
		var seconds := int(timer) % 60
		timer_label.text = "%d:%02d" % [minutes, seconds]
	if door_label:
		door_label.text = "DOOR: %d" % door_hp
		# Color shifts as door health gets low
		if door_hp <= 5:
			door_label.modulate = Color(1.0, 0.2, 0.2)
		elif door_hp <= 10:
			door_label.modulate = Color(1.0, 0.7, 0.2)
		else:
			door_label.modulate = Color(0.8, 0.8, 0.8)
