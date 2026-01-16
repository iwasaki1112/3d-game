# CharacterRegistry API

`extends Node` (Autoload Singleton)

キャラクタープリセットの管理とキャラクター生成を担当するシングルトン。

## ファイル

`scripts/registries/character_registry.gd`

## Autoload設定

`project.godot`で以下のように登録済み：

```
[autoload]
CharacterRegistry="*res://scripts/registries/character_registry.gd"
```

---

## Constants

| Constant | Value | Description |
|----------|-------|-------------|
| `ANIMATION_SOURCE` | `"res://assets/animations/character_anims.glb"` | 共有アニメーションファイルパス |
| `PRESET_DIR` | `"res://data/characters/"` | プリセット格納ディレクトリ |

---

## 初期化

起動時に自動的に以下を実行：

1. `ANIMATION_SOURCE`から共有アニメーションライブラリを読み込み
2. `PRESET_DIR`内の全`.tres`ファイルをCharacterPresetとして読み込み
3. チーム別にインデックス化

```
CharacterRegistry: Loaded 52 animations from character_anims.glb
CharacterRegistry: Loaded 2 presets
```

---

## Methods

### Query Methods

#### get_preset

```gdscript
func get_preset(id: String) -> CharacterPreset
```

IDでプリセットを取得。

| Parameter | Type | Description |
|-----------|------|-------------|
| `id` | `String` | プリセットID |

**Returns**: `CharacterPreset`、存在しない場合は`null`

---

#### has_preset

```gdscript
func has_preset(id: String) -> bool
```

プリセットの存在を確認。

| Parameter | Type | Description |
|-----------|------|-------------|
| `id` | `String` | プリセットID |

**Returns**: 存在する場合`true`

---

#### get_all

```gdscript
func get_all() -> Array
```

登録済みの全プリセットを取得。

**Returns**: `Array[CharacterPreset]`

---

#### get_by_team

```gdscript
func get_by_team(team: GameCharacter.Team) -> Array
```

指定チームのプリセット一覧を取得。

| Parameter | Type | Description |
|-----------|------|-------------|
| `team` | `GameCharacter.Team` | チーム（NONE, CT, T） |

**Returns**: `Array[CharacterPreset]`

---

#### get_terrorists

```gdscript
func get_terrorists() -> Array
```

Terroristチームの全プリセットを取得。

**Returns**: `Array[CharacterPreset]`

---

#### get_counter_terrorists

```gdscript
func get_counter_terrorists() -> Array
```

Counter-Terroristチームの全プリセットを取得。

**Returns**: `Array[CharacterPreset]`

---

### Factory Methods

#### create_character

```gdscript
func create_character(preset_id: String, position: Vector3 = Vector3.ZERO) -> Node
```

プリセットIDからキャラクターを生成。

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `preset_id` | `String` | - | プリセットID |
| `position` | `Vector3` | `Vector3.ZERO` | 生成位置 |

**Returns**: `GameCharacter`インスタンス、失敗時は`null`

**失敗条件**:
- プリセットが存在しない
- プリセットの`model_scene`が未設定

---

#### create_character_from_preset

```gdscript
func create_character_from_preset(preset: CharacterPreset, position: Vector3 = Vector3.ZERO) -> Node
```

プリセットオブジェクトからキャラクターを生成。

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `preset` | `CharacterPreset` | - | プリセットオブジェクト |
| `position` | `Vector3` | `Vector3.ZERO` | 生成位置 |

**Returns**: `GameCharacter`インスタンス、失敗時は`null`

**生成されるノード構造**:

```
GameCharacter
├── CharacterModel (preset.model_sceneをインスタンス化)
│   ├── Armature
│   │   └── Skeleton3D
│   │       └── MeshInstance3D
│   └── AnimationPlayer (共有アニメーションライブラリ付き)
├── CollisionShape3D
│   └── CapsuleShape3D (radius=0.3, height=1.8)
└── CharacterAnimationController (walk_speed, run_speed設定済み)
```

**自動設定される値**:
- `GameCharacter.name` = `preset.id`
- `GameCharacter.max_health` = `preset.max_health`
- `GameCharacter.team` = `preset.team`
- `GameCharacter.position` = `position`
- `CharacterAnimationController.walk_speed` = `preset.walk_speed`
- `CharacterAnimationController.run_speed` = `preset.run_speed`

---

### Registration Methods

#### register

```gdscript
func register(preset: CharacterPreset) -> void
```

プリセットを手動登録。通常は自動読み込みされるため、ランタイムで動的に追加する場合に使用。

| Parameter | Type | Description |
|-----------|------|-------------|
| `preset` | `CharacterPreset` | 登録するプリセット |

**注意**:
- `preset.id`が空の場合は登録されない
- 同じIDが既に存在する場合は警告が出て登録されない

---

#### unregister

```gdscript
func unregister(id: String) -> void
```

プリセットを登録解除。

| Parameter | Type | Description |
|-----------|------|-------------|
| `id` | `String` | 解除するプリセットID |

---

## 使用例

### 基本的なキャラクター生成

```gdscript
# IDから生成
var character = CharacterRegistry.create_character("soldier_t", Vector3(0, 0, 5))
if character:
    add_child(character)

# プリセットから生成
var preset = CharacterRegistry.get_preset("soldier_ct")
if preset:
    var character = CharacterRegistry.create_character_from_preset(preset, spawn_point)
    add_child(character)
```

### チーム選択UI

```gdscript
func _populate_team_selection():
    # Terrorist選択肢
    for preset in CharacterRegistry.get_terrorists():
        var btn = Button.new()
        btn.text = preset.display_name
        btn.tooltip_text = preset.description
        btn.pressed.connect(_on_character_selected.bind(preset.id))
        terrorist_container.add_child(btn)

    # Counter-Terrorist選択肢
    for preset in CharacterRegistry.get_counter_terrorists():
        var btn = Button.new()
        btn.text = preset.display_name
        btn.tooltip_text = preset.description
        btn.pressed.connect(_on_character_selected.bind(preset.id))
        ct_container.add_child(btn)

func _on_character_selected(preset_id: String):
    selected_preset_id = preset_id
    _spawn_player()

func _spawn_player():
    var character = CharacterRegistry.create_character(selected_preset_id, spawn_point)
    game_world.add_child(character)
    player_controller.possess(character)
```

### プリセット情報表示

```gdscript
func _show_character_info(preset_id: String):
    var preset = CharacterRegistry.get_preset(preset_id)
    if not preset:
        return

    name_label.text = preset.display_name
    desc_label.text = preset.description
    health_label.text = "HP: %d" % preset.max_health
    speed_label.text = "Speed: %.1f / %.1f" % [preset.walk_speed, preset.run_speed]

    if preset.portrait:
        portrait_rect.texture = preset.portrait
    if preset.icon:
        icon_rect.texture = preset.icon
```

### ランダムスポーン

```gdscript
func spawn_random_terrorist(spawn_pos: Vector3) -> GameCharacter:
    var terrorists = CharacterRegistry.get_terrorists()
    if terrorists.is_empty():
        return null

    var preset = terrorists[randi() % terrorists.size()]
    return CharacterRegistry.create_character_from_preset(preset, spawn_pos)
```

### 動的プリセット登録

```gdscript
func _register_custom_character():
    var preset = CharacterPreset.new()
    preset.id = "custom_soldier"
    preset.display_name = "Custom Soldier"
    preset.team = GameCharacter.Team.TERRORIST
    preset.model_scene = load("res://assets/characters/custom/soldier.glb")
    preset.max_health = 150.0

    CharacterRegistry.register(preset)
```

---

## アニメーション共有の仕組み

1. 起動時に`ANIMATION_SOURCE`（GLB）からAnimationLibraryを抽出
2. キャラクター生成時、モデルのAnimationPlayerに共有ライブラリを設定
3. 全キャラクターが同じアニメーションセットを使用

**利点**:
- メモリ効率が良い
- アニメーション更新が一箇所で完結
- 新キャラクター追加時にアニメーション設定不要

---

## ディレクトリ構成

```
DefuseForge/
├── scripts/
│   └── registries/
│       └── character_registry.gd   # このファイル
│
├── data/
│   └── characters/                  # PRESET_DIR
│       ├── dummy_ct.tres
│       └── dummy_t.tres
│
└── assets/
    └── animations/
        └── character_anims.glb      # ANIMATION_SOURCE (52 animations)
```

---

## 関連

- [GameCharacter](game-character.md)
- [CharacterPreset](character-preset.md)
- [CharacterAnimationController](character-animation-controller.md)
