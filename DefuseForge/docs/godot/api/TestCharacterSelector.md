# TestCharacterSelector

キャラクター選択テストシーン。CharacterRegistryからキャラクターをテストするデバッグツール。

## 基本情報

| 項目 | 値 |
|------|-----|
| 継承元 | `Node3D` |
| ファイルパス | `scripts/tests/test_character_selector.gd` |
| シーン | `scenes/tests/test_character.tscn` |

## 機能

- 起動時に2体のCTキャラクターを自動生成
- マウスクリックでキャラクター選択
- クリックでコンテキストメニュー表示
- ドロップダウンからキャラクター追加
- パス描画によるキャラクター移動（複数キャラクター対応）
- 視線ポイント設定（Slice the Pie）
- 全キャラクター同時実行
- 回転モードで向き変更
- しゃがみ/立ちトグル
- WASD/マウスによる手動操作（トグル可能）

## 操作方法

### 基本操作
| 操作 | 説明 |
|------|------|
| クリック（キャラクター上） | 選択 + コンテキストメニュー表示 |
| クリック（キャラクター外） | 選択解除 + メニュー閉じる |
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

### パスモード（複数キャラクター対応）
1. キャラクターをクリックしてコンテキストメニューで「Move」選択
2. マウスドラッグでパス描画
3. 視線ポイントモードに自動移行
4. 「Add Vision」ボタンでパス上をクリック→ドラッグで視線方向設定
5. 「Confirm Path」ボタンでパスを確定（パスは表示され続ける）
6. 別のキャラクターに対して1-5を繰り返し
7. 「Execute All (Walk/Run)」ボタンで全キャラクター同時実行
8. 全キャラクター到着後にパスと視線マーカーが自動削除

### 回転モード
1. コンテキストメニューで「Rotate」選択
2. 地面をクリックして向きを設定
3. Confirm/Cancelで確定

## コンテキストメニュー項目

| ID | 名前 | 説明 |
|----|------|------|
| `move` | Move | パス描画モード開始 |
| `rotate` | Rotate | 回転モード開始 |
| `crouch` | Crouch/Stand | しゃがみ/立ちトグル（状態により表示変化） |

## UIパネル

### ControlPanel（左上、常時表示）
| ボタン | 説明 |
|--------|------|
| Manual Control | 手動操作のON/OFF切替 |
| Vision/FoW | 視界/Fog of WarのON/OFF切替 |
| Pending: N paths | 確定済みパス数の表示 |
| Execute All (Walk) | 全キャラクターを歩きで同時実行 |
| Execute All (Run) | 全キャラクターを走りで同時実行 |
| Clear All Paths | 全ての確定パスをクリア |

### PathPanel（パス描画後、画面下部）
| ボタン | 説明 |
|--------|------|
| Vision Points: N | 設定済み視線ポイント数 |
| Add Vision | 視線ポイント追加モード |
| Undo | 最後の視線ポイントを削除 |
| Confirm Path | パスを確定して保存 |
| Cancel | パス描画をキャンセル |

## State Variables

| 変数 | 型 | 説明 |
|------|-----|------|
| `is_debug_control_enabled` | `bool` | 手動操作有効フラグ |
| `is_vision_enabled` | `bool` | 視界/FoW有効フラグ |
| `is_path_mode` | `bool` | パス描画モード中 |
| `path_editing_character` | `Node` | パス編集中のキャラクター |
| `pending_paths` | `Dictionary` | キャラクターごとの確定パス |
| `characters` | `Array[Node]` | シーン内の全キャラクター |
| `selected_character` | `Node` | 選択中のキャラクター |

## シーン構成

```
TestCharacterSelector (Node3D)
├── Camera3D
├── UI (CanvasLayer)
│   ├── CharacterDropdown
│   ├── InfoLabel
│   ├── ControlPanel
│   │   ├── ManualControlButton
│   │   ├── VisionToggleButton
│   │   ├── Separator
│   │   ├── PendingPathsLabel
│   │   ├── ExecuteWalkButton
│   │   ├── ExecuteRunButton
│   │   └── ClearPathsButton
│   ├── PathPanel
│   │   ├── VisionLabel
│   │   ├── VisionHBox/AddVisionButton, UndoVisionButton
│   │   ├── ConfirmButton
│   │   └── CancelButton
│   └── RotatePanel
│       ├── RotateConfirmButton
│       └── RotateCancelButton
├── Floor (CSGBox3D)
└── Wall (CSGBox3D)
```

## 内部クラス依存

- `CharacterRegistry` - キャラクター作成
- `FogOfWarSystem` - 視界表示
- `ContextMenuComponent` - コンテキストメニュー
- `PathDrawer` - パス描画
- `PathFollowingController` - パス追従（キャラクターごとに動的生成）
- `CharacterRotationController` - 回転制御
- `CharacterAnimationController` - アニメーション制御
- `PathLineMesh` - 確定パスの表示
