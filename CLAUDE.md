# Claude Code Rules (Godot開発)

## プロジェクト情報
- **エンジン**: Godot 4.5.1
- **プロジェクトパス**: `DefuseForge/`
- **言語**: GDScript

## 現在の状態
開発途中。テストシーン：
- `scenes/tests/test_animation_viewer.tscn` - アニメーション確認用
- `scenes/tests/test_path_drawer.tscn` - パス描画・移動確認用

## ドキュメント
`docs/godot/` 配下：
- `architecture.md` - システムアーキテクチャ概要、コンポーネント依存関係、シグナルフロー
- `character-api.md` - CharacterBase/CharacterAPI（選択、回転、移動、武器、アニメーション、IK、レーザー、視界、FogOfWar、レジストリ、ユーティリティクラス、リソース定義）
- `skeleton-modifier-patterns.md` - SkeletonModifier3D、上半身回転、IK実行順序
- `testing-guide.md` - テストシーンの使い方、デバッグツール

**重要**:
- 実装前に関連ドキュメントを読むこと（特に `architecture.md` と `character-api.md`）
- 仕様追加・変更があった場合は `docs/godot/character-api.md` に定義を追記すること

## コマンド
```bash
# エディタ起動
"/Applications/Godot.app/Contents/MacOS/Godot" --path DefuseForge --editor

# プロジェクト実行
"/Applications/Godot.app/Contents/MacOS/Godot" --path DefuseForge
```

## Tool Priority
1. **Godot MCP** (優先) - シーン作成・編集・実行
2. **GDScript LSP** (`gdscript-lsp`) - シンボル検索、コード解析
3. **ファイル操作** (フォールバック) - スクリプト編集
