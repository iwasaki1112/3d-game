# DefuseForge テストガイド

このドキュメントでは、テストシーンの使い方とデバッグツールについて説明します。

---

## 1. テストシーン一覧

| シーン | 場所 | 用途 |
|--------|------|------|
| `test_animation_viewer.tscn` | `scenes/tests/` | アニメーション確認・武器装着テスト |
| `test_path_drawer.tscn` | `scenes/tests/` | パス描画・移動・視界テスト |

---

## 2. test_animation_viewer.tscn

### 2.1 概要

複数キャラクターのアニメーションと武器装着を確認するためのシーンです。

### 2.2 構成

- **キャラクター**: Vanguard x2, Phantom x2（4体）
- **チーム分け**: Team 1 (CT), Team 2 (T)
- **UI**: アニメーション選択パネル
- **カメラ**: OrbitCamera（ドラッグで回転）

### 2.3 操作方法

| 操作 | 説明 |
|------|------|
| 左ドラッグ | カメラ回転 |
| マウスホイール | ズームイン/アウト |
| アニメーションボタン | 選択アニメーションを再生 |

### 2.4 確認できる機能

- 各アニメーションの再生
- 武器装着時の左手IK
- 上半身回転（エイミング）
- チームごとの表示

---

## 3. test_path_drawer.tscn

### 3.1 概要

パス描画・移動実行・視界システムをテストするシーンです。

### 3.2 構成

- **キャラクター**: Vanguard x1
- **UI**: Clear Path / Execute ボタン
- **システム**: PathDrawer, ContextMenu, FogOfWar

### 3.3 操作方法

| 操作 | 説明 |
|------|------|
| キャラクターをクリック | 選択 + コンテキストメニュー表示 |
| 「Move」選択 | パス描画モード開始 |
| 地面をクリック | ウェイポイント追加 |
| 「AddVision」選択 | 視界ポイント追加 |
| 「Execute」選択 | パス実行 |
| 「Clear」選択 | パスクリア |

### 3.4 ワークフロー

```
1. キャラクターをクリック
2. コンテキストメニューから「Move」を選択
3. 地面をクリックしてウェイポイントを追加
4. （オプション）「AddVision」で視界ポイントを追加
5. 「Execute」で移動実行
6. 移動完了後、視界ポイントでスパイン回転を確認
```

### 3.5 確認できる機能

- パス描画（赤いライン）
- ウェイポイント（マーカー）
- 視界ポイント（青いマーカー）
- Fog of War（視界ポリゴン）
- 移動アニメーション（Walk/Run）
- スパイン回転（視界方向への回転）

---

## 4. デバッグツール

### 4.1 orbit_camera.gd

**用途**: テストシーン用の軌道カメラ

**機能**:
- マウスドラッグでターゲット周りを回転
- ホイールでズーム
- 注視点の追従

**パラメータ**:
```gdscript
@export var target: Node3D           # 注視対象
@export var distance: float = 5.0    # 初期距離
@export var rotation_speed: float    # 回転速度
@export var zoom_speed: float        # ズーム速度
```

### 4.2 check_animations.gd

**用途**: AnimationPlayer のアニメーション一覧を確認

**使い方**:
1. スクリプトをノードにアタッチ
2. `target` に AnimationPlayer を持つノードを設定
3. 実行時に出力パネルにアニメーション一覧が表示される

**出力例**:
```
=== Animations in character ===
- rifle_idle
- rifle_walking
- rifle_sprint
- rifle_shoot
- rifle_dying
...
```

### 4.3 compare_skeletons.gd

**用途**: 2つのスケルトンの骨名を比較

**使い方**:
1. スクリプトをノードにアタッチ
2. `skeleton_a` と `skeleton_b` を設定
3. 実行時に骨名の差分が出力される

**出力例**:
```
=== Skeleton Comparison ===
Common bones: 55
Only in A: ["extra_bone"]
Only in B: []
```

**用途例**:
- 新しいキャラクターモデルの互換性確認
- 骨名規約の違いの特定

---

## 5. エディタからの起動

### 5.1 コマンドライン

```bash
# エディタ起動
"/Applications/Godot.app/Contents/MacOS/Godot" --path DefuseForge --editor

# プロジェクト実行（デフォルトシーン）
"/Applications/Godot.app/Contents/MacOS/Godot" --path DefuseForge

# 特定シーンを実行
"/Applications/Godot.app/Contents/MacOS/Godot" --path DefuseForge \
  scenes/tests/test_path_drawer.tscn
```

### 5.2 MCP経由

```javascript
// Godot MCP を使用
mcp__godot__run_project({
  projectPath: "DefuseForge",
  scene: "scenes/tests/test_path_drawer.tscn"
})
```

---

## 6. デバッグ出力

### 6.1 よく使うログパターン

| プレフィックス | コンポーネント |
|---------------|----------------|
| `[CharacterBase]` | キャラクター本体 |
| `[MovementComponent]` | 移動 |
| `[AnimationComponent]` | アニメーション |
| `[WeaponComponent]` | 武器・IK |
| `[VisionComponent]` | 視界 |

### 6.2 push_error vs push_warning

- `push_error`: 処理が続行不能なエラー
- `push_warning`: 処理は続行可能だが注意が必要

---

## 7. トラブルシューティング

### 7.1 アニメーションが再生されない

1. AnimationPlayer が存在するか確認
2. アニメーション名が正しいか確認（`check_animations.gd` 使用）
3. AnimationTree が active か確認

### 7.2 IKが効かない

1. WeaponResource の `left_hand_ik_enabled` が true か確認
2. 武器シーンに LeftHandGrip マーカーがあるか確認
3. 骨名が BoneNameRegistry の候補に含まれるか確認

### 7.3 視界が表示されない

1. VisionComponent の `wall_collision_mask` が正しいか確認
2. FogOfWarSystem がシーンに存在するか確認
3. 壁オブジェクトが "walls" グループに含まれるか確認

### 7.4 パスが描画されない

1. PathDrawer がシーンに存在するか確認
2. ナビゲーションメッシュが設定されているか確認
3. コリジョンレイヤーが正しいか確認

---

## 関連ドキュメント

- [architecture.md](./architecture.md) - アーキテクチャ概要
- [character-api.md](./character-api.md) - 詳細API仕様
