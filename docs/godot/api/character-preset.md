# CharacterPreset API

`extends Resource`

キャラクターのメタデータを定義するリソースクラス。`.tres`ファイルとして保存し、CharacterRegistryで管理される。

## ファイル

`scripts/resources/character_preset.gd`

---

## Properties

### Basic Info

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `id` | `String` | `""` | 一意識別子（例: `"soldier_t"`, `"bomber_ct"`） |
| `display_name` | `String` | `""` | UI表示名 |
| `description` | `String` | `""` | キャラクター説明文 |

### Team

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `team` | `GameCharacter.Team` | `NONE` | 所属チーム |

### Model

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `model_scene` | `PackedScene` | `null` | キャラクターモデル（GLBファイル） |

### Stats

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `max_health` | `float` | `100.0` | 最大HP |
| `walk_speed` | `float` | `2.5` | 歩行速度 |
| `run_speed` | `float` | `5.0` | 走行速度 |

### UI

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `icon` | `Texture2D` | `null` | 選択UI用アイコン |
| `portrait` | `Texture2D` | `null` | 詳細表示用ポートレート |

---

## ファイル形式

### 基本構造

```
[gd_resource type="Resource" script_class="CharacterPreset" load_steps=N format=3]

[ext_resource type="Script" path="res://scripts/resources/character_preset.gd" id="1_preset"]
[ext_resource type="PackedScene" path="res://assets/characters/.../model.glb" id="2_model"]

[resource]
script = ExtResource("1_preset")
id = "unique_id"
display_name = "Display Name"
description = "Character description"
team = 1  # 0=NONE, 1=CT, 2=T
model_scene = ExtResource("2_model")
max_health = 100.0
walk_speed = 2.5
run_speed = 5.0
```

### 例: Terrorist

`data/characters/dummy_t.tres`:

```
[gd_resource type="Resource" script_class="CharacterPreset" load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/resources/character_preset.gd" id="1_preset"]
[ext_resource type="PackedScene" path="res://assets/characters/terrorist/dummy/dummy_t.glb" id="2_model"]

[resource]
script = ExtResource("1_preset")
id = "dummy_t"
display_name = "Dummy"
description = "Terrorist training dummy"
team = 2
model_scene = ExtResource("2_model")
max_health = 100.0
walk_speed = 2.5
run_speed = 5.0
```

### 例: Counter-Terrorist

`data/characters/dummy_ct.tres`:

```
[gd_resource type="Resource" script_class="CharacterPreset" load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/resources/character_preset.gd" id="1_preset"]
[ext_resource type="PackedScene" path="res://assets/characters/counter_terrorist/dummy/dummy_ct.glb" id="2_model"]

[resource]
script = ExtResource("1_preset")
id = "dummy_ct"
display_name = "Dummy"
description = "Counter-Terrorist training dummy"
team = 1
model_scene = ExtResource("2_model")
max_health = 100.0
walk_speed = 2.5
run_speed = 5.0
```

---

## プリセット作成手順

### Godotエディタで作成

1. `data/characters/`フォルダを右クリック
2. 「新規リソース」を選択
3. `CharacterPreset`を検索して選択
4. インスペクタで各プロパティを設定
5. `character_id.tres`として保存

### 手動で作成

1. 上記のファイル形式を参考にテキストファイルを作成
2. `.tres`拡張子で保存
3. `data/characters/`に配置

---

## モデル要件

CharacterRegistryで正しく動作するために、`model_scene`のGLBは以下の構造を持つ必要がある：

```
RootNode (Node3D)
└── Armature (Node3D)
    └── Skeleton3D
        └── MeshInstance3D (skin付き)
```

**注意**: AnimationPlayerは自動的に追加され、共有アニメーションライブラリが設定される。

---

## 使用例

### プリセット取得

```gdscript
# IDで取得
var preset = CharacterRegistry.get_preset("soldier_t")
if preset:
    print("Name: %s" % preset.display_name)
    print("Team: %d" % preset.team)
    print("Health: %d" % preset.max_health)
```

### チーム別取得

```gdscript
# Terrorist一覧
for preset in CharacterRegistry.get_terrorists():
    print("[T] %s - %s" % [preset.id, preset.display_name])

# Counter-Terrorist一覧
for preset in CharacterRegistry.get_counter_terrorists():
    print("[CT] %s - %s" % [preset.id, preset.display_name])
```

### キャラクター生成

```gdscript
var preset = CharacterRegistry.get_preset("bomber_t")
var character = CharacterRegistry.create_character_from_preset(preset, spawn_pos)
add_child(character)
```

---

## ディレクトリ構成

```
DefuseForge/
├── data/
│   └── characters/
│       ├── dummy_ct.tres      # CT プリセット
│       ├── dummy_t.tres       # T プリセット
│       ├── soldier_ct.tres    # 追加キャラクター例
│       └── bomber_t.tres      # 追加キャラクター例
│
└── assets/
    └── characters/
        ├── counter_terrorist/
        │   ├── dummy/
        │   │   └── dummy_ct.glb
        │   └── soldier/
        │       └── soldier.glb
        └── terrorist/
            ├── dummy/
            │   └── dummy_t.glb
            └── bomber/
                └── bomber.glb
```

---

## 関連

- [GameCharacter](game-character.md)
- [CharacterRegistry](character-registry.md)
