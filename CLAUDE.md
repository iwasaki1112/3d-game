# Claude Code Rules (Godot開発)

## プロジェクト情報
- **エンジン**: Godot 4.5.1
- **プロジェクトパス**: `SupportRateGame/`
- **言語**: GDScript

## ドキュメント参照
詳細な仕様は以下のドキュメントを参照すること：

| ドキュメント | 内容 |
|------------|------|
| `docs/GAME_DESIGN.md` | ゲーム設計・仕様 |
| `docs/CHARACTER_API.md` | キャラクターAPI |
| `docs/WEAPON_API.md` | 武器システムAPI |
| `docs/WEAPON_GUIDE.md` | 武器追加ガイド（Blender操作含む） |
| `docs/BLENDER_ANIMATION.md` | Blenderアニメーション設定 |

## Tool Priority
1. **Godot MCP** (優先) - シーン作成・編集・プロジェクト実行
2. **ファイル操作** (フォールバック) - スクリプト編集・シーンファイル直接編集

## よく使うコマンド
```bash
# Godotエディタを開く
"/Users/iwasakishungo/Downloads/Godot.app/Contents/MacOS/Godot" --path SupportRateGame --editor

# プロジェクトを実行
"/Users/iwasakishungo/Downloads/Godot.app/Contents/MacOS/Godot" --path SupportRateGame
```

## iOS実機ビルド
**必ず専用スクリプトを使用すること！**
```bash
./scripts/ios_build.sh --export
```
※ `--export`オプション必須。Godotの`--export-debug`を直接実行しないこと。

## Error handling
- シーンが読み込めない → UIDを確認
- スクリプトエラー → Godotコンソール確認（`get_debug_output`）
- 影が表示されない → マテリアルがPBR（shading_mode=1）か確認
