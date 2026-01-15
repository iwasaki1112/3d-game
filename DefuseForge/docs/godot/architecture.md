# DefuseForge アーキテクチャ概要

このドキュメントでは、DefuseForge のシステムアーキテクチャと各コンポーネントの関係性を説明します。

---

## 1. 全体構成

```
DefuseForge/
├── scripts/
│   ├── api/                    # 高レベルAPI
│   │   └── character_api.gd    # CharacterAPI（静的ユーティリティ）
│   ├── characters/             # キャラクターシステム
│   │   ├── character_base.gd   # CharacterBase（中央オーケストレーター）
│   │   └── components/         # コンポーネント（7つ）
│   │       ├── animation_component.gd
│   │       ├── health_component.gd
│   │       ├── input_rotation_component.gd
│   │       ├── movement_component.gd
│   │       ├── outline_component.gd
│   │       ├── vision_component.gd
│   │       └── weapon_component.gd
│   ├── effects/                # 視覚エフェクト
│   ├── managers/               # グローバル状態管理
│   │   ├── character_interaction_manager.gd
│   │   ├── player_manager.gd   # Autoload
│   │   └── selection_manager.gd
│   ├── registries/             # リソースレジストリ
│   │   ├── character_registry.gd
│   │   └── weapon_registry.gd
│   ├── resources/              # データリソース
│   ├── systems/                # ゲームシステム
│   │   └── fog_of_war_system.gd
│   ├── ui/                     # UI コンポーネント
│   └── utils/                  # ユーティリティ
│       ├── animation_fallback.gd
│       ├── bone_name_registry.gd
│       ├── position_helper.gd
│       ├── raycast_helper.gd
│       ├── two_bone_ik_3d.gd
│       ├── upper_body_rotation_modifier.gd
│       └── vision_math.gd
├── scenes/                     # シーン
│   ├── effects/                # エフェクトシーン
│   ├── tests/                  # テストシーン
│   └── weapons/                # 武器シーン
└── assets/                     # 3Dモデル、テクスチャ
```

---

## 2. コンポーネントアーキテクチャ

### 2.1 クラス階層

```
CharacterBody3D (Godot)
    └── CharacterBase
        ├── コンポーネント（子ノードとして動的追加）
        │   ├── MovementComponent      # 移動・パスファインディング
        │   ├── AnimationComponent     # アニメーション管理
        │   ├── WeaponComponent        # 武器・IK
        │   ├── HealthComponent        # HP・ダメージ
        │   ├── VisionComponent        # 視界計算
        │   ├── OutlineComponent       # 選択アウトライン
        │   └── InputRotationComponent # マウス回転
        └── SkeletonModifier3D
            ├── UpperBodyRotationModifier  # 上半身回転
            └── TwoBoneIK3D               # 左手IK
```

### 2.2 コンポーネント依存関係

```
CharacterBase ─────────────────┐
    │                          │
    ├── MovementComponent      │
    │       │                  │
    │       ├── NavigationAgent3D
    │       └── 移動マーカー   │
    │                          │
    ├── AnimationComponent ────┤
    │       │                  │
    │       ├── AnimationPlayer
    │       ├── AnimationTree  │
    │       └── UpperBodyRotationModifier
    │                          │
    ├── WeaponComponent ───────┤
    │       │                  │
    │       ├── BoneAttachment3D
    │       ├── TwoBoneIK3D    │
    │       └── WeaponRegistry │
    │                          │
    ├── VisionComponent ───────┤
    │       │                  │
    │       └── FogOfWarSystem │
    │                          │
    └── HealthComponent        │
            │                  │
            └── signals ───────┘
```

---

## 3. Manager層

### 3.1 PlayerManager（Autoload）

- **役割**: チーム管理、プレイヤーキャラクター一覧
- **スコープ**: グローバル（シングルトン）
- **主要メソッド**:
  - `register_character(character, team)`
  - `get_team_characters(team)`
  - `switch_active_team()`

### 3.2 SelectionManager

- **役割**: キャラクター選択状態の管理
- **スコープ**: シーン単位
- **シグナル**:
  - `character_selected(character)`
  - `character_deselected(character)`

### 3.3 CharacterInteractionManager

- **役割**: UIワークフローのオーケストレーション
- **状態マシン**: IDLE → MENU_OPEN → ROTATING → IDLE
- **連携**:
  - SelectionManager
  - ContextMenuComponent
  - InputRotationComponent

---

## 4. シグナルフロー

### 4.1 選択・コンテキストメニュー

```
ユーザークリック
    │
    ▼
InputRotationComponent.clicked
    │
    ▼
CharacterInteractionManager
    │
    ├── SelectionManager.select()
    │
    └── ContextMenuComponent.show()

メニュー項目選択
    │
    ▼
CharacterInteractionManager._on_action_selected()
    │
    ├── MovementComponent.add_move_action()
    ├── VisionComponent.add_vision_point()
    └── ...
```

### 4.2 移動・アニメーション

```
MovementComponent.move_along_path()
    │
    ├── locomotion_changed シグナル
    │       │
    │       ▼
    │   AnimationComponent.set_locomotion()
    │       │
    │       ▼
    │   AnimationTree パラメータ更新
    │
    └── vision_direction_changed シグナル
            │
            ▼
        AnimationComponent.apply_spine_rotation()
            │
            ▼
        UpperBodyRotationModifier 回転適用
```

### 4.3 ダメージ・死亡

```
WeaponComponent.fire()
    │
    ▼
RayCast3D.is_colliding()
    │
    ▼
HealthComponent.take_damage()
    │
    ├── damaged シグナル
    │
    └── (HP <= 0)
        │
        ▼
        died シグナル
            │
            ▼
        AnimationComponent.play_death_animation()
            │
            ▼
        VisionComponent.disable()
```

---

## 5. 初期化順序

### 5.1 CharacterBase._ready()

```
1. _find_skeleton()
2. _setup_components()
   ├── MovementComponent.new() + setup()
   ├── AnimationComponent.new() + setup()
   ├── WeaponComponent.new() + setup()
   ├── HealthComponent.new() + setup()
   ├── VisionComponent.new() （子として追加）
   ├── OutlineComponent.new() + setup()
   └── InputRotationComponent.new() （子として追加）
3. シグナル接続
```

### 5.2 SkeletonModifier3D 実行順序

AnimationTree が更新された後、`skeleton_updated` シグナルで以下が順次実行：

1. **UpperBodyRotationModifier** - 上半身回転（スパイン/胸）
2. **TwoBoneIK3D** - 左手IK（武器装着時のみ）

---

## 6. Registry パターン

### 6.1 構造

```
WeaponRegistry (静的クラス)
    │
    ├── enum WeaponId { NONE, AK47, M4A1, ... }
    ├── enum WeaponType { NONE, RIFLE, PISTOL, ... }
    │
    ├── const WEAPON_PATHS := { WeaponId: "res://..." }
    │
    └── static func get_weapon(id) → WeaponResource
```

### 6.2 キャッシュ戦略

- 初回ロード時にキャッシュ
- 同一IDへの2回目以降のアクセスは O(1)

---

## 7. ユーティリティクラス

| クラス | 用途 |
|--------|------|
| `BoneNameRegistry` | 複数スケルトン規約の骨名検索 |
| `RaycastHelper` | レイキャスト処理の簡素化 |
| `AnimationFallback` | アニメーション候補のフォールバック検索 |
| `VisionMath` | FOV計算、角度ラッピング |
| `PositionHelper` | 目線・胴体位置の計算 |

---

## 8. 設計原則

1. **コンポジション優先**: 継承より組み合わせを重視
2. **シグナルによる疎結合**: コンポーネント間の依存を最小化
3. **リソース駆動**: CharacterResource/WeaponResource でデータ分離
4. **静的レジストリ**: 明示的なID-パスマッピングで安全なリソース管理
5. **SkeletonModifier3D活用**: アニメーション後処理の標準パターン

---

## 関連ドキュメント

- [character-api.md](./character-api.md) - 詳細API仕様
- [skeleton-modifier-patterns.md](./skeleton-modifier-patterns.md) - SkeletonModifier3D パターン
- [testing-guide.md](./testing-guide.md) - テストシーンガイド
