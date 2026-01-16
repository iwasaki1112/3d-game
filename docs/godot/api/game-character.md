# GameCharacter API

`extends CharacterBody3D`

キャラクターの状態管理を担当するベースクラス。アニメーション制御はCharacterAnimationControllerに委譲。

## ファイル

`scripts/characters/game_character.gd`

---

## Enum

### Team

```gdscript
enum Team {
    NONE = 0,
    COUNTER_TERRORIST = 1,
    TERRORIST = 2
}
```

---

## Signals

| Signal | Parameters | Description |
|--------|------------|-------------|
| `died` | `killer: Node3D` | HP が 0 になり死亡した時 |
| `damaged` | `amount: float, attacker: Node3D, is_headshot: bool` | ダメージを受けた時 |
| `healed` | `amount: float` | 回復した時 |

---

## Properties

### Export Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `max_health` | `float` | `100.0` | 最大HP |
| `team` | `Team` | `Team.NONE` | 所属チーム |

### State Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `current_health` | `float` | `100.0` | 現在HP |
| `is_alive` | `bool` | `true` | 生存状態 |
| `anim_ctrl` | `Node` | `null` | CharacterAnimationController参照 |

---

## Methods

### HP管理

#### take_damage

```gdscript
func take_damage(amount: float, attacker: Node3D = null, is_headshot: bool = false) -> void
```

ダメージを与える。HPが0以下になると自動的に死亡処理が実行される。

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `amount` | `float` | - | ダメージ量 |
| `attacker` | `Node3D` | `null` | 攻撃者（死亡アニメーション方向計算に使用） |
| `is_headshot` | `bool` | `false` | ヘッドショットフラグ |

**動作**:
1. `is_alive`が`false`の場合は何もしない
2. `current_health`から`amount`を減算
3. `damaged`シグナルを発火
4. HPが0以下になった場合、`_die()`を呼び出し

---

#### heal

```gdscript
func heal(amount: float) -> void
```

HPを回復する。`max_health`を超えない。

| Parameter | Type | Description |
|-----------|------|-------------|
| `amount` | `float` | 回復量 |

**動作**:
1. `is_alive`が`false`の場合は何もしない
2. `current_health`に`amount`を加算（`max_health`が上限）
3. 実際に回復した場合、`healed`シグナルを発火

---

#### get_health_ratio

```gdscript
func get_health_ratio() -> float
```

HP割合を取得。

**Returns**: `current_health / max_health`（0.0〜1.0）

---

#### reset_health

```gdscript
func reset_health() -> void
```

HPを全回復し、`is_alive`を`true`に設定。リスポーン処理に使用。

---

### チーム判定

#### is_enemy_of

```gdscript
func is_enemy_of(other: GameCharacter) -> bool
```

対象が敵チームかを判定。

| Parameter | Type | Description |
|-----------|------|-------------|
| `other` | `GameCharacter` | 判定対象 |

**Returns**:
- `true`: 異なるチームに所属
- `false`: 同じチーム、または一方が`Team.NONE`

---

### アニメーション連携

#### set_anim_controller

```gdscript
func set_anim_controller(controller: Node) -> void
```

CharacterAnimationControllerを設定。

---

#### get_anim_controller

```gdscript
func get_anim_controller() -> Node
```

設定済みのCharacterAnimationControllerを取得。

---

## 死亡処理

`take_damage()`でHPが0以下になると、内部で`_die()`が呼び出され以下が実行される：

1. `is_alive = false`に設定
2. 攻撃者の位置から被弾方向を計算
3. CharacterAnimationController経由で死亡アニメーション再生
4. CollisionShape3Dを無効化
5. `died`シグナル発火

---

## 使用例

### 基本的な継承

```gdscript
extends GameCharacter

func _ready() -> void:
    super._ready()
    team = Team.TERRORIST

    # アニメーションコントローラー設定
    var ctrl = CharacterAnimationController.new()
    add_child(ctrl)
    ctrl.setup($CharacterModel, $CharacterModel/AnimationPlayer)
    set_anim_controller(ctrl)

func _physics_process(delta: float) -> void:
    if not is_alive:
        return

    # 移動処理...
    anim_ctrl.update_animation(move_dir, aim_dir, is_running, delta)
```

### ダメージ処理

```gdscript
# 通常ダメージ
target.take_damage(25.0, attacker)

# ヘッドショット
target.take_damage(100.0, attacker, true)

# 回復
target.heal(50.0)

# HP確認
var hp_percent = target.get_health_ratio() * 100
print("HP: %d%%" % hp_percent)
```

### 死亡シグナル監視

```gdscript
character.died.connect(_on_character_died)
character.damaged.connect(_on_character_damaged)

func _on_character_died(killer: Node3D):
    if killer:
        print("%s was killed by %s" % [character.name, killer.name])
    else:
        print("%s died" % character.name)

func _on_character_damaged(amount: float, attacker: Node3D, is_headshot: bool):
    if is_headshot:
        print("Headshot! %d damage" % amount)
```

### 敵味方判定

```gdscript
func can_attack(target: GameCharacter) -> bool:
    return is_enemy_of(target) and target.is_alive
```

---

## 関連

- [CharacterPreset](character-preset.md)
- [CharacterRegistry](character-registry.md)
- [CharacterAnimationController](character-animation-controller.md)
- [VisionComponent](vision-component.md)
