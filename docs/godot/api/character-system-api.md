# Character System API Overview

キャラクター管理システムの概要とクラス一覧。

## クラス一覧

| クラス | ファイル | 説明 |
|--------|---------|------|
| [GameCharacter](game-character.md) | `scripts/characters/game_character.gd` | キャラクター本体（HP、チーム、死亡状態） |
| [CharacterPreset](character-preset.md) | `scripts/resources/character_preset.gd` | キャラクター定義リソース |
| [CharacterRegistry](character-registry.md) | `scripts/registries/character_registry.gd` | プリセット管理・キャラクター生成（Autoload） |

---

## アーキテクチャ

```
CharacterRegistry (Autoload)
    │
    ├── 起動時読み込み
    │   ├── character_anims.glb → 共有AnimationLibrary (52個)
    │   └── data/characters/*.tres → CharacterPreset[]
    │
    └── create_character() ──► GameCharacter
                                    │
                                    ├── CharacterModel (GLB)
                                    │   ├── Armature/Skeleton3D
                                    │   └── AnimationPlayer
                                    │
                                    ├── CollisionShape3D
                                    │
                                    └── CharacterAnimationController
```

---

## クイックリファレンス

### キャラクター生成

```gdscript
# IDから生成
var char = CharacterRegistry.create_character("soldier_t", spawn_pos)
add_child(char)

# プリセットから生成
var preset = CharacterRegistry.get_preset("soldier_ct")
var char = CharacterRegistry.create_character_from_preset(preset, spawn_pos)
add_child(char)
```

### チーム別取得

```gdscript
var terrorists = CharacterRegistry.get_terrorists()
var cts = CharacterRegistry.get_counter_terrorists()
var all = CharacterRegistry.get_all()
```

### ダメージ処理

```gdscript
target.take_damage(25.0, attacker)        # 通常ダメージ
target.take_damage(100.0, attacker, true) # ヘッドショット
target.heal(50.0)                         # 回復
```

### シグナル

```gdscript
character.died.connect(_on_died)
character.damaged.connect(_on_damaged)
character.healed.connect(_on_healed)
```

### チーム判定

```gdscript
if character.is_enemy_of(other):
    # 敵として処理
```

---

## ファイル構成

```
DefuseForge/
├── scripts/
│   ├── characters/
│   │   └── game_character.gd
│   ├── resources/
│   │   └── character_preset.gd
│   └── registries/
│       └── character_registry.gd
│
├── data/
│   └── characters/
│       ├── dummy_ct.tres
│       └── dummy_t.tres
│
└── assets/
    ├── animations/
    │   └── character_anims.glb
    └── characters/
        ├── counter_terrorist/
        │   └── dummy/dummy_ct.glb
        └── terrorist/
            └── dummy/dummy_t.glb
```

---

## 関連API

- [CharacterAnimationController](character-animation-controller.md)
