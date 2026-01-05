extends "res://scripts/systems/path/path_manager.gd"
## テスト用PathManager
## SquadManager依存を排除し、単一プレイヤーで動作

## テスト用：プレイヤー検出距離
var tap_detection_radius: float = 2.0


func _ready() -> void:
	# 親クラスの_ready()を呼ばずに、必要な初期化だけ行う
	# （親の_ready()はInputManagerシグナルを親メソッドに接続してしまうため）

	# アナライザーの初期化
	var PathAnalyzerClass = preload("res://scripts/systems/path/path_analyzer.gd")
	analyzer = PathAnalyzerClass.new()

	# InputManagerに接続（子クラスのメソッドに接続）
	if has_node("/root/InputManager"):
		var input_manager = get_node("/root/InputManager")
		input_manager.draw_started.connect(_on_draw_started)
		input_manager.draw_moved.connect(_on_draw_moved)
		input_manager.draw_ended.connect(_on_draw_ended)
		print("[TestPathManager] Connected to InputManager signals")
	else:
		push_warning("[TestPathManager] InputManager not found!")

	print("[TestPathManager] Ready")  # 検出範囲を広げる


## オーバーライド：位置にいるプレイヤーを取得
## SquadManagerなしで動作するようにシンプル化
func _get_player_at_position(world_pos: Vector3) -> Node3D:
	if not player:
		print("[TestPathManager] _get_player_at_position: player is null")
		return null

	# プレイヤーとの距離をチェック
	var player_pos := player.global_position
	player_pos.y = world_pos.y  # Y軸を揃えて比較
	var distance := player_pos.distance_to(world_pos)

	print("[TestPathManager] _get_player_at_position: world_pos=%s, player_pos=%s, distance=%.2f" % [world_pos, player_pos, distance])

	if distance <= tap_detection_radius:
		print("[TestPathManager] Player detected!")
		return player

	print("[TestPathManager] Player NOT detected (too far)")
	return null


## オーバーライド：プレイヤーを切り替え（テストでは不要）
func _switch_to_player(_new_player: Node3D) -> void:
	pass  # テストでは単一プレイヤーなので何もしない


## オーバーライド：選択解除（テストでは何もしない）
func _deselect_current_player() -> void:
	pass  # テストでは選択解除しない


## オーバーライド：パス描画可否（常に許可）
func _can_draw() -> bool:
	return true


## オーバーライド：描画開始（デバッグ用）
func _on_draw_started(screen_pos: Vector2, world_pos: Vector3) -> void:
	print("[TestPathManager] _on_draw_started: screen=%s, world=%s" % [screen_pos, world_pos])

	# 親クラスのメソッドを呼び出し
	super._on_draw_started(screen_pos, world_pos)

	print("[TestPathManager] After super._on_draw_started: is_drawing=%s, current_path.size=%d" % [is_drawing, current_path.size()])


## オーバーライド：描画中の処理
## フリーハンドでパスを描画（グリッドチェックなし）
func _on_draw_moved(_screen_pos: Vector2, world_pos: Vector3) -> void:
	if world_pos == Vector3.INF:
		return

	if not is_drawing:
		return

	# 最小距離チェック
	if current_path.size() > 0:
		var last_pos := current_path[current_path.size() - 1]
		var distance := world_pos.distance_to(last_pos)
		if distance < min_point_distance:
			return

	# フリーハンドでポイントを追加（グリッドチェックなし）
	current_path.append(world_pos)
	_update_visual()
	_update_path_time()


## オーバーライド：描画終了
## グリッドシステムを完全にバイパスしてフリーハンドパスを使用
func _on_draw_ended(_screen_pos: Vector2) -> void:
	print("[TestPathManager] _on_draw_ended: is_drawing=%s, current_path.size=%d" % [is_drawing, current_path.size()])

	if not is_drawing:
		return

	is_drawing = false

	if current_path.size() >= 2 and player:
		# グリッド変換なしでそのままフリーハンドパスを使用

		# 走り判定（グリッドなし、アナライザー使用）
		run_flags = analyzer.analyze(current_path)

		# プレイヤーのパスデータを保存
		_save_player_path(player, current_path.duplicate(), run_flags.duplicate())
		_update_visual()

		# waypointsを生成
		var waypoints: Array = []
		for i in range(current_path.size()):
			var run := false
			if i > 0 and i - 1 < run_flags.size():
				run = run_flags[i - 1]
			waypoints.append({
				"position": current_path[i],
				"run": run
			})

		path_confirmed.emit(waypoints)

	print("[TestPathManager] After _on_draw_ended: is_drawing=%s" % is_drawing)
