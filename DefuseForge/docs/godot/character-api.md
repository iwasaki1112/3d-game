# CharacterAPI リファレンス

キャラクター操作の統一API。CharacterBaseインスタンスの生成、配置、アニメーション、武器、IK操作を提供。

## 基本的な使い方

```gdscript
const CharacterAPI = preload("res://scripts/api/character_api.gd")

# アニメーション再生
CharacterAPI.play_animation(character, "idle", 0.3)

# キャラクター切り替え
CharacterAPI.switch_character_model(character, "phantom")
```

## Animation API

### get_available_animations
```gdscript
static func get_available_animations(character: CharacterBase, filtered: bool = true) -> Array[String]
```
利用可能なアニメーション一覧を取得。`filtered=true`で優先アニメーションのみ返す。

### play_animation
```gdscript
static func play_animation(character: CharacterBase, animation_name: String, blend_time: float = 0.3) -> void
```
アニメーションを再生。

### setup_animations
```gdscript
static func setup_animations(character: CharacterBase, character_id: String) -> void
```
キャラクターIDに基づいてアニメーションを自動セットアップ。アニメーション共有（phantom→vanguard）を自動処理。

### copy_animations_from
```gdscript
static func copy_animations_from(character: CharacterBase, source_character_id: String) -> void
```
別キャラクターからアニメーションをコピー。同じARPリグを使用するキャラクター間で使用。

## Model Switching API

### switch_character_model
```gdscript
static func switch_character_model(
    character: CharacterBase,
    character_id: String,
    weapon_id: int = -1
) -> bool
```
キャラクターモデルを切り替える。以下を自動処理:
1. 古いモデル削除
2. 新モデル読み込み
3. コンポーネント再初期化（`reload_model()`）
4. アニメーションセットアップ
5. 武器再装備
6. キャラクター固有IKオフセット適用

**パラメータ:**
- `character`: 対象CharacterBase
- `character_id`: "vanguard", "phantom"等
- `weapon_id`: 切り替え後の武器ID（-1で現在の武器を維持）

**使用例:**
```gdscript
# 武器を維持してキャラクター切り替え
CharacterAPI.switch_character_model(player, "phantom")

# 武器も指定して切り替え
CharacterAPI.switch_character_model(player, "vanguard", WeaponRegistry.WeaponId.M4A1)
```

## Weapon IK Tuning API

武器のIK（左手）を調整するAPI。主にデバッグ・チューニング用。

### update_elbow_pole_position
```gdscript
static func update_elbow_pole_position(character: CharacterBase, x: float, y: float, z: float) -> void
```
肘ポール位置を更新。IKの肘の曲がり方向を制御。

### update_left_hand_position
```gdscript
static func update_left_hand_position(character: CharacterBase, x: float, y: float, z: float) -> void
```
左手IKターゲット位置を更新。

### set_character_ik_offset
```gdscript
static func set_character_ik_offset(character: CharacterBase, hand_offset: Vector3, elbow_offset: Vector3) -> void
```
キャラクター固有のIKオフセットを設定。腕の長さが異なるキャラクター間での補正に使用。

### apply_character_ik_from_resource
```gdscript
static func apply_character_ik_from_resource(character: CharacterBase, character_id: String) -> void
```
CharacterResourceからIKオフセットを自動適用。`switch_character_model`内部で自動呼び出しされる。

## Laser Pointer API

### toggle_laser
```gdscript
static func toggle_laser(character: CharacterBase) -> void
```
レーザーポインターをトグル。

### set_laser_active
```gdscript
static func set_laser_active(character: CharacterBase, active: bool) -> void
```
レーザーポインターの状態を明示的に設定。

## アニメーション共有マッピング

`ANIMATION_SOURCE`定数で定義。同じARPリグを使用するキャラクター間でアニメーションを共有:

```gdscript
const ANIMATION_SOURCE := {
    "phantom": "vanguard"   # phantomはvanguardのアニメーションを使用
}
```

新しいキャラクターを追加する場合、ここにマッピングを追加。

## CharacterBaseの関連メソッド

CharacterAPIは内部でCharacterBaseのメソッドを呼び出す:

### reload_model
```gdscript
func reload_model(new_model: Node3D = null) -> void
```
モデルをリロードし、全コンポーネントを再初期化。モデル入れ替え後に呼び出す。

```gdscript
# 低レベル操作（通常はswitch_character_modelを使用）
var new_model = load("res://path/to/model.glb").instantiate()
character.add_child(new_model)
character.reload_model(new_model)
```

## Input Rotation Component

マウスでキャラクターをクリック＆ドラッグして回転させるコンポーネント。

**ファイル:** `scripts/characters/components/input_rotation_component.gd`

### セットアップ

```gdscript
const InputRotationComponentScript = preload("res://scripts/characters/components/input_rotation_component.gd")

func _ready():
    var rotation = InputRotationComponentScript.new()
    rotation.name = "InputRotationComponent"
    character_body.add_child(rotation)
    rotation.setup(camera)  # Raycast用カメラ参照

    # シグナル接続（任意）
    rotation.rotation_started.connect(_on_rotation_started)
    rotation.rotation_ended.connect(_on_rotation_ended)
```

### プロパティ

| プロパティ | 型 | デフォルト | 説明 |
|------------|-----|----------|------|
| `click_radius` | float | 1.5 | クリック判定の近接半径（メートル） |
| `character_collision_mask` | int | 1 | Raycast用の衝突マスク |
| `ground_plane_height` | float | 0.0 | 地面の高さ（Y座標） |
| `hold_duration` | float | 0.2 | 長押し判定時間（秒） |

### メソッド

#### setup
```gdscript
func setup(camera: Camera3D) -> void
```
Raycast用のカメラ参照を設定。マウス2D座標→3Dワールド座標変換に使用。

#### is_rotating
```gdscript
func is_rotating() -> bool
```
現在回転操作中かどうかを返す。

### シグナル

| シグナル | 発火タイミング |
|----------|----------------|
| `rotation_started` | キャラクター付近をクリックした時 |
| `rotation_ended` | マウスボタンを離した時 |

### 動作フロー

1. **クリック判定**: 左クリック時にRaycastでキャラクターに当たるか判定
2. **近接フォールバック**: Raycastが外れても `click_radius` 以内ならOK
3. **長押し待機**: `hold_duration` 秒間押し続けると回転モード開始
4. **回転**: ドラッグ中、マウス位置と地面の交点に向けてキャラクターを回転
5. **終了**: マウスボタンを離すと `rotation_ended` 発火

### 使用例：カメラ連携

```gdscript
# 回転中はカメラ操作を無効化
rotation.rotation_started.connect(func(): camera.input_disabled = true)
rotation.rotation_ended.connect(func(): camera.input_disabled = false)
```

## Animation Component

キャラクターのアニメーション管理コンポーネント。

**ファイル:** `scripts/characters/components/animation_component.gd`

### 上半身回転API

#### apply_spine_rotation
```gdscript
func apply_spine_rotation(yaw_degrees: float, pitch_degrees: float = 0.0) -> void
```
上半身の目標回転角度を設定。内部でlerp補間される。

#### get_current_aim_rotation
```gdscript
func get_current_aim_rotation() -> Vector2
```
現在の補間後の上半身回転角度を取得（ラジアン）。
- `x`: ヨー（水平回転）
- `y`: ピッチ（垂直回転）

VisionComponentがFoW視界方向の計算に使用。

---

## Vision Component

キャラクターの視界（FOV）を管理するコンポーネント。シャドウキャスト方式で壁の遮蔽を計算し、Fog of Warシステムと連携。

**ファイル:** `scripts/characters/components/vision_component.gd`

### プロパティ

| プロパティ | 型 | デフォルト | 説明 |
|------------|-----|----------|------|
| `fov_degrees` | float | 90.0 | 視野角（度） |
| `view_distance` | float | 15.0 | 視界距離（メートル） |
| `edge_ray_count` | int | 30 | FOV境界のレイ数 |
| `update_interval` | float | 0.033 | 更新間隔（秒） |
| `eye_height` | float | 1.5 | 目の高さ |
| `wall_collision_mask` | int | 2 | 壁検出用コリジョンマスク |

### メソッド

#### get_visible_polygon
```gdscript
func get_visible_polygon() -> PackedVector3Array
```
現在の視界ポリゴン（頂点配列）を取得。FogOfWarSystemが使用。

#### force_update
```gdscript
func force_update() -> void
```
即座に視界を再計算。

#### set_fov / set_view_distance
```gdscript
func set_fov(degrees: float) -> void
func set_view_distance(distance: float) -> void
```
視野角・視界距離を変更。

#### disable / enable
```gdscript
func disable() -> void
func enable() -> void
```
視界の無効化/有効化（死亡時など）。disable時は空のポリゴンをemitする。

### シグナル

| シグナル | パラメータ | 説明 |
|----------|------------|------|
| `vision_updated` | `visible_points: PackedVector3Array` | 視界ポリゴン更新時 |
| `wall_hit_updated` | `hit_points: PackedVector3Array` | 壁衝突点更新時 |

### 視界方向の計算（AnimationComponent連携）

VisionComponentはAnimationComponentの`get_current_aim_rotation()`を使用して視界方向を計算する。これにより**頭部の向きとFoWの視界が完全に同期**する。

```
視界方向 = キャラクター基本向き(basis.z) + 上半身回転(AnimationComponent)
```

**内部動作:**
1. `_get_effective_look_direction()`でAnimationComponentの回転を取得
2. キャラクターの基本向き（basis.z）に回転を適用
3. `atan2(direction.x, -direction.z)`で角度計算（Godotは-Zが前方）

---

## Fog of War システム統合

### シーンへの統合方法

```gdscript
const FogOfWarSystemScript = preload("res://scripts/systems/fog_of_war_system.gd")

func _setup_fog_of_war() -> void:
    fog_of_war_system = Node3D.new()
    fog_of_war_system.set_script(FogOfWarSystemScript)
    fog_of_war_system.name = "FogOfWarSystem"
    add_child(fog_of_war_system)

    await get_tree().process_frame
    # PlayerManagerはAutoload（preload不要）
    if character and character.vision and PlayerManager.is_player_team(character.team):
        fog_of_war_system.register_vision(character.vision)
```

### 注意点

1. **PlayerManagerはAutoload**: `preload`ではなく直接`PlayerManager.xxx()`で参照
2. **視界方向の座標系**: Godotは-Zが前方。`atan2(x, -z)`で角度計算
3. **回転の符号**: `forward.rotated(Vector3.UP, yaw)` - 符号に注意

---

## 設計原則

1. **CharacterAPIを経由**: 直接`character.weapon.xxx()`を呼ばず、CharacterAPIを使用
2. **nullチェック内蔵**: すべてのAPIメソッドはnullチェックを行い、警告を出力
3. **静的メソッド**: すべてのAPIは`static func`で、第一引数にcharacterを取る

---

## ユーティリティクラス

### BoneNameRegistry

複数のスケルトン規約（Humanoid、ARP、Blender Rigify）に対応した骨名検索。

```gdscript
# 右手骨のインデックスを検索
var bone_idx = BoneNameRegistry.find_right_hand_bone(skeleton)

# 左手骨名を検索
var bone_name = BoneNameRegistry.find_left_hand_bone_name(skeleton)

# 上半身骨のリストを取得
var upper_bones = BoneNameRegistry.get_upper_body_bones(skeleton)

# 骨名が上半身かどうか判定
var is_upper = BoneNameRegistry.is_upper_body_bone("Spine")
```

**対応規約:**
| 規約 | 例 |
|------|-----|
| Humanoid/Mixamo | `RightHand`, `LeftUpperArm` |
| Blender Rigify | `hand.r`, `arm.l` |
| Auto-Rig Pro | `c_hand_ik.r`, `c_arm_ik.l` |

### RaycastHelper

レイキャスト処理を簡素化するユーティリティ。

```gdscript
# 基本レイキャスト
var result = RaycastHelper.cast_ray(space_state, from, to, mask, exclude)

# カメラからのレイキャスト
var result = RaycastHelper.cast_ray_from_camera(camera, mouse_pos, space_state, mask)

# 視線遮蔽チェック
var blocked = RaycastHelper.is_line_of_sight_blocked(space_state, eye, target, wall_mask)

# 地面との交点
var point = RaycastHelper.get_ground_intersection(camera, mouse_pos, ground_height)
```

### VisionMath

視界計算に使用する数学関数。

```gdscript
# 角度を -PI 〜 PI にラップ
var wrapped = VisionMath.wrap_angle(angle)

# FOV内判定
var in_fov = VisionMath.is_in_fov(forward, to_target, fov_degrees)

# 方向ベクトルから回転角度
var rotation = VisionMath.direction_to_rotation(direction)
```

### PositionHelper

位置計算ユーティリティ。

```gdscript
# 目線位置を取得
var eye_pos = PositionHelper.get_eye_position(character_pos, 1.5)

# 胴体位置を取得
var body_pos = PositionHelper.get_body_position(target_pos)

# 水平距離
var dist = PositionHelper.get_horizontal_distance(from, to)
```

### AnimationFallback

アニメーション候補のフォールバック検索。

```gdscript
# 候補リストから存在するアニメーションを検索
var anim = AnimationFallback.find_animation(anim_player, candidates, default)

# 死亡アニメーションを検索
var death = AnimationFallback.get_death_animation(anim_player, "rifle")
```

---

## リソース定義

### CharacterResource

キャラクターの設定データ。

| プロパティ | 型 | 説明 |
|-----------|-----|------|
| `character_id` | String | キャラクター識別子 |
| `display_name` | String | 表示名 |
| `model_path` | String | モデルシーンパス |
| `weapon_attach_offset` | Vector3 | 武器装着位置オフセット |
| `weapon_attach_rotation` | Vector3 | 武器装着回転オフセット |
| `left_hand_offset` | Vector3 | 左手IKオフセット |
| `left_elbow_offset` | Vector3 | 左肘ポールオフセット |
| `max_health` | float | 最大HP |
| `move_speed` | float | 移動速度 |

### WeaponResource

武器の設定データ。

| プロパティ | 型 | 説明 |
|-----------|-----|------|
| `weapon_id` | int | WeaponRegistry.WeaponId |
| `display_name` | String | 表示名 |
| `weapon_type` | int | WeaponRegistry.WeaponType |
| `scene_path` | String | 武器シーンパス |
| `price` | int | 購入価格 |
| `damage` | float | 基本ダメージ |
| `fire_rate` | float | 発射速度 |
| `effective_range` | float | 有効射程 |
| `headshot_multiplier` | float | ヘッドショット倍率 |
| `bodyshot_multiplier` | float | ボディショット倍率 |
| `magazine_size` | int | マガジン容量 |
| `reserve_ammo` | int | 予備弾薬数 |
| `attach_position` | Vector3 | 装着位置 |
| `attach_rotation` | Vector3 | 装着回転 |
| `left_hand_ik_enabled` | bool | 左手IK有効 |
| `left_hand_ik_position` | Vector3 | 左手IK位置 |
| `left_elbow_pole_x/y/z` | float | 肘ポール位置 |

---

## 関連ドキュメント

- [architecture.md](./architecture.md) - アーキテクチャ概要
- [skeleton-modifier-patterns.md](./skeleton-modifier-patterns.md) - SkeletonModifier3D パターン
- [testing-guide.md](./testing-guide.md) - テストガイド
