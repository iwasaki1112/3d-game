# VisionComponent API

`extends Node3D`

キャラクターの視界（FOV）を管理するコンポーネント。シャドウキャスト方式で壁の遮蔽を計算し、FogOfWarSystemと連携。

## ファイル

`scripts/characters/vision_component.gd`

---

## Signals

| Signal | Parameters | Description |
|--------|------------|-------------|
| `vision_updated` | `visible_points: PackedVector3Array` | 視界ポリゴン更新時 |
| `wall_hit_updated` | `hit_points: PackedVector3Array` | 壁衝突点更新時 |

---

## Properties

### Export Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `fov_degrees` | `float` | `90.0` | 視野角（度） |
| `view_distance` | `float` | `15.0` | 視界距離（メートル） |
| `edge_ray_count` | `int` | `30` | FOV境界のレイ数 |
| `update_interval` | `float` | `0.033` | 更新間隔（秒、約30fps） |
| `eye_height` | `float` | `1.5` | 目の高さ |
| `wall_collision_mask` | `int` | `2` | 壁検出用コリジョンマスク |

### State Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `_enabled` | `bool` | `true` | 視界計算の有効/無効 |
| `_visible_polygon` | `PackedVector3Array` | `[]` | 現在の視界ポリゴン |
| `_wall_hit_points` | `PackedVector3Array` | `[]` | 壁ヒットポイント |

---

## Methods

### get_visible_polygon

```gdscript
func get_visible_polygon() -> PackedVector3Array
```

現在の視界ポリゴンを取得。FogOfWarSystemが使用。

**Returns**: 視界ポリゴンの頂点配列（最初の要素は原点）

---

### get_wall_hit_points

```gdscript
func get_wall_hit_points() -> PackedVector3Array
```

壁にヒットした点の配列を取得。

**Returns**: 壁衝突点の配列

---

### force_update

```gdscript
func force_update() -> void
```

即座に視界を再計算。通常は`update_interval`ごとに自動更新されるが、即時更新が必要な場合に使用。

---

### set_fov

```gdscript
func set_fov(degrees: float) -> void
```

視野角を変更。

| Parameter | Type | Description |
|-----------|------|-------------|
| `degrees` | `float` | 新しい視野角（1.0〜360.0） |

---

### set_view_distance

```gdscript
func set_view_distance(distance: float) -> void
```

視界距離を変更。

| Parameter | Type | Description |
|-----------|------|-------------|
| `distance` | `float` | 新しい視界距離（最小1.0） |

---

### disable

```gdscript
func disable() -> void
```

視界を無効化。死亡時などに使用。空のポリゴンをemitする。

---

### enable

```gdscript
func enable() -> void
```

視界を有効化。リスポーン時などに使用。

---

### is_enabled

```gdscript
func is_enabled() -> bool
```

視界が有効かどうかを返す。

---

## シャドウキャスト方式

VisionComponentはシャドウキャスト方式で視界を計算する。

### 動作原理

1. **FOV境界にレイを配置**: `edge_ray_count`本のレイをFOV範囲内に均等配置
2. **壁コーナーを検出**: シーン内のCSGBox3D（collision_layer=2）とStaticBody3D（"walls"グループ）からコーナーを収集
3. **コーナーへ追加レイ**: 各コーナーの少し左右（±0.002rad）にもレイを発射し、エッジを滑らかに
4. **ポリゴン構築**: レイの結果から視界ポリゴンを構築

### 壁の設定

壁としてVisionComponentに認識されるには以下のいずれかが必要：

**CSGBox3D**:
- `use_collision = true`
- `collision_layer` にビット2が含まれる

**StaticBody3D**:
- "walls"グループに追加
- 子にBoxShape3Dを持つCollisionShape3D

---

## GameCharacterとの連携

GameCharacterには`setup_vision()`メソッドがあり、VisionComponentを自動作成・設定できる。

```gdscript
# GameCharacter内で
var vision = character.setup_vision(90.0, 15.0)
```

死亡時に自動でdisable、リスポーン時に自動でenableされる。

---

## FogOfWarSystemとの連携

```gdscript
const FogOfWarSystemScript = preload("res://scripts/systems/fog_of_war_system.gd")

func _setup_fog_of_war() -> void:
    fog_of_war_system = Node3D.new()
    fog_of_war_system.set_script(FogOfWarSystemScript)
    add_child(fog_of_war_system)

    # VisionComponentを登録
    await get_tree().process_frame
    fog_of_war_system.register_vision(character.vision)
```

---

## 視界方向

VisionComponentはキャラクターの向きを以下の優先順位で取得：

1. **CharacterAnimationController**: `get_look_direction()`（モデルの実際の向き）
2. **フォールバック**: キャラクターの`global_transform.basis.z`

これにより、アニメーション付きキャラクターでは**頭部の向きとFoWの視界が同期**する。

---

## 使用例

### 基本的な使用

```gdscript
# VisionComponentを手動作成
var vision = VisionComponent.new()
vision.name = "VisionComponent"
vision.fov_degrees = 120.0
vision.view_distance = 20.0
character.add_child(vision)
character.vision = vision

# シグナル接続
vision.vision_updated.connect(_on_vision_updated)

func _on_vision_updated(polygon: PackedVector3Array):
    print("Vision polygon has %d points" % polygon.size())
```

### GameCharacter経由

```gdscript
# 簡単なセットアップ
var vision = character.setup_vision(90.0, 15.0)

# FogOfWarSystemに登録
fog_system.register_vision(vision)
```

### 動的な視野変更

```gdscript
# スナイパースコープ使用時
func _on_scope_in():
    character.vision.set_fov(30.0)
    character.vision.set_view_distance(50.0)

func _on_scope_out():
    character.vision.set_fov(90.0)
    character.vision.set_view_distance(15.0)
```

### 死亡・リスポーン

```gdscript
# GameCharacterが自動処理するが、手動でも可能
character.died.connect(func(_k): character.vision.disable())

func respawn():
    character.reset_health()  # 内部でvision.enable()も呼ばれる
```

---

## 関連

- [GameCharacter](game-character.md)
- [FogOfWarSystem](fog-of-war-system.md)
- [CharacterAnimationController](character-animation-controller.md)
