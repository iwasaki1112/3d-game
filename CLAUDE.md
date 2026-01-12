# Claude Code Rules (Godot開発)

## プロジェクト情報
- **エンジン**: Godot 4.5.1
- **プロジェクトパス**: `DefuseForge/`
- **言語**: GDScript
- **メインシーン**: `scenes/tests/test_animation_viewer.tscn`

## 現在の状態
プロジェクトは開発途中で、現在は **test_animation_viewer** のみが稼働しています。
ゲーム本体のシーン（title, game, lobby等）は削除済みです。

## スキル

### プロジェクトスキル
| スキル | 用途 |
|--------|------|
| `/add-weapon` | 武器追加ガイド（Blenderモデル準備→WeaponResource作成→左手IK調整） |
| `/export-character` | BlenderからキャラクターをGLBエクスポート（NLAアニメーション含む）→Godotに配置 |
| `/organize-arp-collection` | ARPでRig&Bind後のコレクション構造を整理。character1→キャラクター名にリネーム、csコレクションを非表示に設定。 |
| `/retarget-animation` | MixamoアニメーションをAuto-Rig Proでリターゲット→NLAトラックにPush Down |
| `/sakurai-review` | 桜井政博氏の哲学に基づくゲーム設計レビュー（リスク/リターン、難易度曲線等） |
| `/difficulty-design` | 難易度設計支援（デコボコ曲線、3分間の法則、救済システム） |
| `/reward-design` | 報酬システム設計（報酬サイクル、数値報酬、コレクション要素） |
| `/game-feel` | ゲームの手触りレビュー（ヒットストップ、攻撃モーション、ジャンプ設計）|

### プラグインスキル
| スキル | 用途 |
|--------|------|
| `/claude-mem:mem-search` | 過去セッションのメモリ検索（「前回どうやった？」等） |
| `/claude-mem:troubleshoot` | claude-memのインストール問題診断・修正 |

## プロジェクト構造

### シーン
```
scenes/
├── tests/test_animation_viewer.tscn  # メインシーン（アニメーション確認用）
├── weapons/
│   ├── ak47.tscn
│   └── m4a1.tscn
└── effects/muzzle_flash.tscn
```

### スクリプト
```
scripts/
├── api/character_api.gd              # キャラクター操作API
├── characters/
│   ├── character_base.gd             # キャラクター基底クラス
│   └── components/
│       ├── animation_component.gd
│       ├── health_component.gd
│       ├── movement_component.gd
│       └── weapon_component.gd
├── registries/
│   ├── character_registry.gd
│   └── weapon_registry.gd
├── resources/
│   ├── action_state.gd
│   ├── character_resource.gd
│   └── weapon_resource.gd
├── tests/
│   ├── test_animation_viewer.gd
│   └── orbit_camera.gd
├── effects/muzzle_flash.gd
└── utils/two_bone_ik_3d.gd           # 左手IK
```

## キャラクターアセット
```
assets/characters/
├── shade/shade.glb     # メインキャラクター
└── phantom/phantom.glb # shadeとアニメーション共有
```

## Tool Priority
1. **Godot MCP** (優先) - シーン作成・編集・プロジェクト実行
2. **ファイル操作** (フォールバック) - スクリプト編集・シーンファイル直接編集

## よく使うコマンド
```bash
# Godotエディタを開く
"/Applications/Godot.app/Contents/MacOS/Godot" --path DefuseForge --editor

# プロジェクトを実行
"/Applications/Godot.app/Contents/MacOS/Godot" --path DefuseForge
```

## Error handling
- シーンが読み込めない → UIDを確認
- スクリプトエラー → Godotコンソール確認（`get_debug_output`）
- 影が表示されない → マテリアルがPBR（shading_mode=1）か確認
