# TestCharacterSelector

キャラクター選択テストシーン。CharacterRegistryからキャラクターをテストするデバッグツール。

## 基本情報

| 項目 | 値 |
|------|-----|
| 継承元 | `Node3D` |
| ファイルパス | `scripts/tests/test_character_selector.gd` |
| シーン | `scenes/tests/test_character.tscn` |

## 機能

- マウスクリックでキャラクター選択
- 右クリックでコンテキストメニュー表示
- ドロップダウンからキャラクター追加
- パス描画によるキャラクター移動
- 視線ポイント設定（Slice the Pie）
- 回転モードで向き変更
- WASD/マウスによる手動操作（トグル可能）

## 操作方法

### 基本操作
| 操作 | 説明 |
|------|------|
| 左クリック/右クリック（キャラクター上） | 選択 + コンテキストメニュー表示 |
| ドロップダウン | キャラクター追加 |
| ESC | モードキャンセル |

### 手動操作（Manual Control ON時）
| 操作 | 説明 |
|------|------|
| WASD | 移動 |
| マウス | エイム方向 |
| Shift | 走る |
| C | しゃがみ |
| F | エイム |
| Space + F | 発射 |
| 1 | ライフル装備 |
| 2 | ピストル装備 |
| K | 自殺（テスト用） |
| R | リスポーン |

### パスモード
1. コンテキストメニューで「Move」選択
2. マウスドラッグでパス描画
3. 視線ポイントモードに自動移行
4. パス上をクリック→ドラッグで視線方向設定
5. Execute/Runボタンで実行

### 回転モード
1. コンテキストメニューで「Rotate」選択
2. 地面をクリックして向きを設定
3. Confirm/Cancelで確定

## コンテキストメニュー項目

| ID | 名前 | 説明 |
|----|------|------|
| `move` | Move | パス描画モード開始 |
| `rotate` | Rotate | 回転モード開始 |
| `control` | Control | 手動操作対象に設定 |

## State Variables

| 変数 | 型 | 説明 |
|------|-----|------|
| `is_debug_control_enabled` | `bool` | 手動操作有効フラグ |
| `is_path_mode` | `bool` | パス描画モード中 |
| `is_following_path` | `bool` | パス追従中 |
| `is_rotate_mode` | `bool` | 回転モード中 |

## 使用例（シーン構成）

```
TestCharacterSelector (Node3D)
├── Camera3D
├── UI (CanvasLayer)
│   ├── CharacterDropdown
│   ├── InfoLabel
│   ├── ControlPanel/ManualControlButton
│   ├── PathPanel
│   │   ├── VisionLabel
│   │   ├── VisionHBox/AddVisionButton, UndoVisionButton
│   │   ├── ExecuteButton
│   │   ├── RunButton
│   │   └── CancelButton
│   └── RotatePanel
│       ├── RotateConfirmButton
│       └── RotateCancelButton
├── Floor (CSGBox3D)
└── Walls (CSGBox3D...)
```

## 内部クラス依存

- `CharacterRegistry` - キャラクター作成
- `FogOfWarSystem` - 視界表示
- `ContextMenuComponent` - コンテキストメニュー
- `PathDrawer` - パス描画
- `CharacterAnimationController` - アニメーション制御
