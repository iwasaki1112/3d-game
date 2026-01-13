# キャラクター API

CharacterBase のパブリック API リファレンス。

## アウトライン（選択ハイライト）

キャラクター選択時にシルエットのみ発光するアウトラインエフェクト。

### 技術実装

SubViewport マスク + Sobel エッジ検出方式:
1. キャラクターメッシュを専用 SubViewport に白色でレンダリング
2. キャンバス上でエッジ検出シェーダーを適用
3. シルエット外縁のみを発光表示

### 初期化

```gdscript
# メインカメラ取得後に呼び出し必須
character.setup_outline_camera(camera)
```

### 選択状態の制御

```gdscript
# 選択状態を設定
character.set_selected(true)
character.set_selected(false)

# 選択状態を取得
var is_selected: bool = character.is_selected()
```

### カスタマイズ

```gdscript
# アウトライン色を設定（デフォルト: シアン）
character.set_outline_color(Color(0.0, 0.8, 1.0, 1.0))

# アウトライン幅を設定（デフォルト: 2.0）
character.set_outline_width(3.0)
```

### OutlineComponent エクスポート設定

| パラメータ | 型 | デフォルト | 説明 |
|------------|------|------------|------|
| outline_color | Color | (0.0, 0.8, 1.0, 1.0) | シアン色 |
| line_width | float | 2.0 | アウトライン太さ |
| emission_energy | float | 1.0 | 発光強度 |

### 注意事項

- `setup_outline_camera()` はカメラ取得後に必ず呼び出す
- LaserPointer など特定ノードはアウトライン対象外
- レイヤー20をマスク用に使用（メインカメラから自動除外）

### 関連ファイル

- `scripts/characters/components/outline_component.gd` - アウトライン管理
- `shaders/silhouette_mask.gdshader` - マスク描画シェーダー
- `shaders/silhouette_edge_detect.gdshader` - エッジ検出シェーダー

---

## 移動

```gdscript
# パスを設定して移動開始
character.set_path(points: Array[Vector3], run: bool = false)

# 単一目標地点に移動
character.move_to(target: Vector3, run: bool = false)

# 移動を停止
character.stop()

# 走る/歩くを切り替え
character.set_running(running: bool)

# 移動中かどうか
var moving: bool = character.is_moving()
```

## 武器

```gdscript
# 武器を設定
character.set_weapon(weapon_id: int)

# 現在の武器IDを取得
var id: int = character.get_weapon_id()

# 武器リソースを取得
var resource: WeaponResource = character.get_weapon_resource()

# リコイルを適用
character.apply_recoil(intensity: float = 1.0)
```

## アニメーション

```gdscript
# アニメーションを再生
character.play_animation(anim_name: String, blend_time: float = 0.3)

# 射撃状態を設定
character.set_shooting(shooting: bool)

# 上半身回転を設定
character.set_upper_body_rotation(degrees: float)

# アニメーションリストを取得
var list: PackedStringArray = character.get_animation_list()
```

## HP

```gdscript
# ダメージを受ける
character.take_damage(amount: float, attacker: Node3D = null, is_headshot: bool = false)

# 回復
character.heal(amount: float)

# HP割合を取得 (0.0〜1.0)
var ratio: float = character.get_health_ratio()

# HPを取得
var hp: float = character.get_health()
```

## アクション

```gdscript
# アクションを開始
character.start_action(action_type: int, duration: float)

# アクションをキャンセル
character.cancel_action()

# アクション中かどうか
var in_action: bool = character.is_in_action()
```

## 視界

```gdscript
# 視野角を設定
character.set_vision_fov(degrees: float)

# 視界距離を設定
character.set_vision_distance(distance: float)

# 視界ポリゴンを取得
var polygon: PackedVector3Array = character.get_vision_polygon()

# 壁ヒットポイントを取得
var hits: PackedVector3Array = character.get_wall_hit_points()
```

## シグナル

```gdscript
signal path_completed
signal waypoint_reached(index: int)
signal died(killer: Node3D)
signal damaged(amount: float, attacker: Node3D, is_headshot: bool)
signal weapon_changed(weapon_id: int)
signal locomotion_changed(state: int)
signal action_started(action_type: int)
signal action_completed(action_type: int)
```
