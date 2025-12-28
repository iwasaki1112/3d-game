extends Node3D

## ゲームシーンのメイン管理
## CS1.6 + Door Kickers 2 スタイル

@onready var player: CharacterBody3D = $Player
@onready var game_ui: CanvasLayer = $GameUI
@onready var path_drawer: Node = null  # 後で追加


func _ready() -> void:
	# プレイヤー参照をGameManagerに設定
	GameManager.player = player

	# ゲームを開始
	GameManager.start_game()

	# パス描画システムの初期化（後で実装）
	_setup_path_system()


func _exit_tree() -> void:
	# シーン終了時にゲームを停止
	GameManager.stop_game()


func _setup_path_system() -> void:
	# PathDrawerの設定（Phase 2で実装）
	pass


## パス描画完了時のコールバック
func _on_path_confirmed(waypoints: Array) -> void:
	if player and player.has_method("set_path"):
		player.set_path(waypoints)
