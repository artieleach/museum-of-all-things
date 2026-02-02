extends Control

@onready var target_label: Label = $MarginContainer/TargetLabel

func _ready() -> void:
	visible = false
	RaceManager.race_started.connect(_on_race_started)
	RaceManager.race_ended.connect(_on_race_ended)
	RaceManager.race_cancelled.connect(_on_race_cancelled)

func _on_race_started(target_article: String) -> void:
	target_label.text = "Target: " + target_article
	visible = true

func _on_race_ended(_winner_peer_id: int, _winner_name: String) -> void:
	visible = false

func _on_race_cancelled() -> void:
	visible = false
