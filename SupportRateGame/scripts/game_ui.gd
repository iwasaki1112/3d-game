extends CanvasLayer

## ゲームUIの管理（CS1.6スタイル）

@onready var timer_label: Label = $MarginContainer/VBoxContainer/TimerLabel
@onready var money_label: Label = $MarginContainer/VBoxContainer/MoneyLabel
@onready var health_label: Label = $MarginContainer/VBoxContainer/HealthLabel
@onready var round_label: Label = $MarginContainer/VBoxContainer/RoundLabel
@onready var game_over_panel: Panel = $GameOverPanel
@onready var final_score_label: Label = $GameOverPanel/VBoxContainer/FinalScoreLabel
@onready var restart_button: Button = $GameOverPanel/VBoxContainer/RestartButton


func _ready() -> void:
	game_over_panel.visible = false
	restart_button.pressed.connect(_on_restart_button_pressed)

	# GameManagerのシグナルに接続
	GameManager.money_changed.connect(_on_money_changed)
	GameManager.game_state_changed.connect(_on_game_state_changed)
	GameManager.round_started.connect(_on_round_started)
	GameManager.round_ended.connect(_on_round_ended)

	# 初期値を設定
	_update_money(GameManager.player_money)
	_update_health(GameManager.player_health)
	_update_round()


func _process(_delta: float) -> void:
	if GameManager.is_game_running:
		_update_timer()
		_update_health(GameManager.player_health)


func _update_timer() -> void:
	var state_prefix := ""
	match GameManager.current_state:
		GameManager.GameState.BUY_PHASE:
			state_prefix = "BUY "
		GameManager.GameState.PLAYING:
			if GameManager.is_bomb_planted:
				state_prefix = "💣 "
			else:
				state_prefix = ""

	timer_label.text = state_prefix + GameManager.get_formatted_time()


func _update_money(amount: int) -> void:
	money_label.text = "$%d" % amount


func _update_health(health: float) -> void:
	health_label.text = "HP: %d" % int(health)
	if GameManager.player_armor > 0:
		health_label.text += " | Armor: %d" % int(GameManager.player_armor)


func _update_round() -> void:
	round_label.text = "CT %d - %d T | Round %d" % [
		GameManager.ct_wins,
		GameManager.t_wins,
		GameManager.current_round
	]


func _on_money_changed(amount: int) -> void:
	_update_money(amount)


func _on_game_state_changed(new_state: GameManager.GameState) -> void:
	match new_state:
		GameManager.GameState.GAME_OVER:
			_show_game_over()
		_:
			pass


func _on_round_started(_round_number: int) -> void:
	_update_round()


func _on_round_ended(winner: GameManager.Team) -> void:
	_update_round()
	# ラウンド終了メッセージを表示（オプション）
	var winner_text := "CT" if winner == GameManager.Team.CT else "Terrorist"
	print("%s wins the round!" % winner_text)


func _show_game_over() -> void:
	game_over_panel.visible = true

	var winner := "CT" if GameManager.ct_wins > GameManager.t_wins else "Terrorist"
	final_score_label.text = "Game Over\n%s Wins!\n\nCT %d - %d T" % [
		winner,
		GameManager.ct_wins,
		GameManager.t_wins
	]


func _on_restart_button_pressed() -> void:
	get_tree().reload_current_scene()
