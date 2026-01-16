# CharacterAnimationController API

キャラクターアニメーション（移動、エイム、戦闘、死亡）を管理するAPIクラス。
内部の複雑さ（AnimationTree、BlendSpace2D、ボーンフィルタ等）を隠蔽し、シンプルなインターフェースを提供する。

## ファイル
- `scripts/animation/character_animation_controller.gd`

---

## クイックスタート

```gdscript
const AnimCtrl = preload("res://scripts/animation/character_animation_controller.gd")

var anim_ctrl: Node

func _ready():
    anim_ctrl = AnimCtrl.new()
    add_child(anim_ctrl)
    anim_ctrl.setup(model, anim_player)

func _physics_process(delta):
    anim_ctrl.update_animation(move_dir, aim_dir, is_running, delta)
```

---

## Enum

### Stance
キャラクターの姿勢状態。

| 値 | 説明 |
|----|------|
| `STAND` | 立ち状態 |
| `CROUCH` | しゃがみ状態 |

### Weapon
武器タイプ。エイムポーズに影響。

| 値 | 説明 |
|----|------|
| `NONE` | 武器なし |
| `RIFLE` | ライフル |
| `PISTOL` | ピストル |

### HitDirection
攻撃を受けた方向。死亡アニメーションに影響。

| 値 | 説明 |
|----|------|
| `FRONT` | 前から |
| `BACK` | 後ろから |
| `LEFT` | 左から |
| `RIGHT` | 右から |

---

## シグナル

### death_finished
死亡アニメーション完了時に発火。

```gdscript
anim_ctrl.death_finished.connect(_on_death)

func _on_death():
    # 死亡後処理（リスポーン等）
    pass
```

### action_finished(action_name: String)
汎用アクションアニメーション完了時に発火。

```gdscript
anim_ctrl.action_finished.connect(_on_action_done)

func _on_action_done(action_name: String):
    print("Completed: ", action_name)
```

---

## メソッド

### 初期化

#### setup(model: Node3D, anim_player: AnimationPlayer) -> void
アニメーションコントローラーを初期化する。

| 引数 | 型 | 説明 |
|------|-----|------|
| model | Node3D | キャラクターモデル（回転制御対象） |
| anim_player | AnimationPlayer | アニメーションプレイヤー |

```gdscript
anim_ctrl.setup($CharacterModel, $CharacterModel/AnimationPlayer)
```

---

### 毎フレーム更新

#### update_animation(movement_direction: Vector3, aim_direction: Vector3, is_running: bool, delta: float) -> void
アニメーション状態を更新する。毎フレーム呼び出す。

| 引数 | 型 | 説明 |
|------|-----|------|
| movement_direction | Vector3 | 移動方向ベクトル（長さ0〜1、Y=0） |
| aim_direction | Vector3 | エイム方向ベクトル（Y=0） |
| is_running | bool | 走り状態 |
| delta | float | デルタタイム |

**内部処理:**
- 移動方向の長さが0 → IDLE
- is_running == true → RUN
- それ以外 → WALK
- モデルをエイム方向に回転
- 8方向ストレイフブレンド計算

```gdscript
func _physics_process(delta):
    var move_dir = Vector3(input_x, 0, input_z)
    var aim_dir = (target_pos - global_position).normalized()
    aim_dir.y = 0

    anim_ctrl.update_animation(move_dir, aim_dir, is_running, delta)
```

---

### 状態設定

#### set_stance(stance: Stance) -> void
姿勢を設定する。

```gdscript
anim_ctrl.set_stance(AnimCtrl.Stance.CROUCH)
```

#### set_weapon(weapon: Weapon) -> void
武器タイプを設定する。エイムポーズが変わる。

```gdscript
anim_ctrl.set_weapon(AnimCtrl.Weapon.PISTOL)
```

#### set_aiming(aiming: bool) -> void
エイム状態を設定する。trueで上半身がエイムポーズになる。

```gdscript
anim_ctrl.set_aiming(true)  # 上半身エイム、下半身は移動継続
```

---

### アクション

#### fire() -> void
射撃リコイルを発動する。発射レート制限あり。

```gdscript
if Input.is_action_pressed("fire"):
    anim_ctrl.fire()
```

#### play_death(hit_direction: HitDirection = FRONT, headshot: bool = false) -> void
死亡アニメーションを再生する。移動を停止し、AnimationTreeを無効化。

| 引数 | 型 | 説明 |
|------|-----|------|
| hit_direction | HitDirection | 攻撃を受けた方向 |
| headshot | bool | ヘッドショットか |

```gdscript
# 前からの攻撃で死亡
anim_ctrl.play_death(AnimCtrl.HitDirection.FRONT, false)

# 後ろからのヘッドショットで死亡
anim_ctrl.play_death(AnimCtrl.HitDirection.BACK, true)
```

#### play_action(action_name: String, stop_movement: bool = true) -> bool
汎用アクションアニメーションを再生する。

| 引数 | 型 | 説明 |
|------|-----|------|
| action_name | String | アニメーション名 |
| stop_movement | bool | 移動を停止するか（デフォルト: true） |

| 戻り値 | 説明 |
|--------|------|
| bool | アニメーションが存在し再生開始したらtrue |

```gdscript
# 扉を開けるアニメーション再生
if anim_ctrl.play_action("open_door"):
    await anim_ctrl.action_finished
    door.open()
```

---

### 状態取得

#### get_current_speed() -> float
現在の状態に応じた移動速度を返す。

| 状態 | 速度 |
|------|------|
| 死亡中 | 0.0 |
| しゃがみ | crouch_speed |
| エイム中 | aim_walk_speed |
| 走り | run_speed |
| 歩き | walk_speed |

```gdscript
velocity = move_dir.normalized() * anim_ctrl.get_current_speed()
```

#### is_dead() -> bool
死亡状態かどうか。

#### is_playing_action() -> bool
アクションアニメーション再生中かどうか。

#### get_current_action() -> String
現在再生中のアクション名。再生中でなければ空文字。

#### get_available_animations() -> PackedStringArray
利用可能なアニメーション名の一覧を取得。デバッグ用。

---

## Export設定

インスペクターから調整可能なパラメータ。

### Movement Speed
| プロパティ | デフォルト | 説明 |
|-----------|-----------|------|
| walk_speed | 2.5 | 歩行速度 |
| run_speed | 5.0 | 走行速度 |
| crouch_speed | 1.5 | しゃがみ移動速度 |
| aim_walk_speed | 2.0 | エイム中歩行速度 |
| rotation_speed | 15.0 | 回転補間速度 |

### Animation Speed Sync
| プロパティ | デフォルト | 説明 |
|-----------|-----------|------|
| anim_walk_speed | 1.4 | 歩行アニメーション基準速度 |
| anim_run_speed | 5.5 | 走行アニメーション基準速度 |
| anim_crouch_speed | 1.2 | しゃがみアニメーション基準速度 |

### Recoil
| プロパティ | デフォルト | 説明 |
|-----------|-----------|------|
| rifle_recoil_strength | 0.08 | ライフルリコイル強度 |
| pistol_recoil_strength | 0.12 | ピストルリコイル強度 |
| rifle_fire_rate | 0.1 | ライフル発射間隔（秒） |
| pistol_fire_rate | 0.2 | ピストル発射間隔（秒） |
| recoil_recovery | 10.0 | リコイル回復速度 |

### Bone Names
| プロパティ | デフォルト | 説明 |
|-----------|-----------|------|
| upper_body_root | mixamorig_Spine1 | 上半身フィルタの起点ボーン |
| spine_bone | mixamorig_Spine2 | リコイル適用ボーン |

---

## 必要なアニメーション

### 移動系（ループ）
| カテゴリ | アニメーション名 |
|---------|----------------|
| 待機 | idle |
| 歩行 | walk_forward, walk_backward, walk_left, walk_right |
| 歩行斜め | walk_forward_left, walk_forward_right, walk_backward_left, walk_backward_right |
| 走行 | run_forward, run_backward, run_left, run_right |
| 走行斜め | run_forward_left, run_forward_right, run_backward_left, run_backward_right |
| しゃがみ待機 | idle_crouching |
| しゃがみ歩行 | walk_crouching_forward, walk_crouching_backward, walk_crouching_left, walk_crouching_right |
| しゃがみ斜め | walk_crouching_forward_left, walk_crouching_forward_right, walk_crouching_backward_left, walk_crouching_backward_right |

### エイム系（ループ）
| アニメーション名 | 説明 |
|----------------|------|
| idle_aiming | ライフル構え |
| idle_crouching_aiming | しゃがみライフル構え |
| pistol_idle | ピストル構え |

### 死亡系（ワンショット）
| アニメーション名 | 説明 |
|----------------|------|
| death_from_the_front | 前から撃たれて倒れる |
| death_from_the_back | 後ろから撃たれて倒れる |
| death_from_right | 右から撃たれて倒れる |
| death_from_front_headshot | 前からヘッドショット |
| death_from_back_headshot | 後ろからヘッドショット |
| death_crouching_headshot_front | しゃがみ中ヘッドショット |

---

## 新しいアニメーション追加手順

### 1. Blenderでアニメーション追加
```
1. FBXをインポート
2. アクション名を変更（例: open_door）
3. mixamo_character.blend を保存
4. GLBをエクスポート
```

### 2. ゲームで使用
```gdscript
# アニメーション再生
anim_ctrl.play_action("open_door")

# 完了を待つ
await anim_ctrl.action_finished

# 完了後処理
door.open()
```

---

## 完全な使用例

```gdscript
extends CharacterBody3D

const AnimCtrl = preload("res://scripts/animation/character_animation_controller.gd")

@onready var model: Node3D = $CharacterModel
@onready var anim_player: AnimationPlayer = $CharacterModel/AnimationPlayer

var anim_ctrl: Node
var aim_position := Vector3.ZERO

func _ready():
    anim_ctrl = AnimCtrl.new()
    add_child(anim_ctrl)
    anim_ctrl.setup(model, anim_player)
    anim_ctrl.set_weapon(AnimCtrl.Weapon.RIFLE)

    # シグナル接続
    anim_ctrl.death_finished.connect(_on_death)
    anim_ctrl.action_finished.connect(_on_action_done)

func _physics_process(delta):
    if anim_ctrl.is_dead():
        return

    # 入力取得
    var move_dir = Vector3(
        Input.get_axis("move_left", "move_right"),
        0,
        Input.get_axis("move_forward", "move_back")
    )
    var aim_dir = (aim_position - global_position)
    aim_dir.y = 0

    # アニメーション更新
    anim_ctrl.update_animation(move_dir, aim_dir, Input.is_action_pressed("run"), delta)

    # 状態設定
    anim_ctrl.set_stance(
        AnimCtrl.Stance.CROUCH if Input.is_action_pressed("crouch")
        else AnimCtrl.Stance.STAND
    )
    anim_ctrl.set_aiming(Input.is_action_pressed("aim"))

    # 射撃
    if Input.is_action_pressed("fire") and anim_ctrl.is_aiming:
        anim_ctrl.fire()

    # 移動
    velocity = move_dir.normalized() * anim_ctrl.get_current_speed()
    move_and_slide()

func take_damage(from_direction: Vector3, is_headshot: bool):
    # ダメージ方向から死亡アニメーション選択
    var hit_dir = _get_hit_direction(from_direction)
    anim_ctrl.play_death(hit_dir, is_headshot)

func _on_death():
    queue_free()  # または リスポーン処理

func _on_action_done(action_name: String):
    print("Action completed: ", action_name)
```
