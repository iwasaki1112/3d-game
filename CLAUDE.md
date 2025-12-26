# Claude Code Rules (Unity開発)

## Goal
UnityMCPを優先的に使用してUnityを操作する。UnityMCPで対応できない場合のみautomation MCPを使用する。

## Tool Priority
1. **UnityMCP** (優先) - Unity Editor APIを直接呼び出せる操作
   - GameObjectの作成・編集・削除
   - コンポーネントの追加・設定
   - シーンの保存・読み込み
   - アセットの操作
   - スクリプトのコンパイル確認

2. **Automation MCP** (フォールバック) - UnityMCPで対応できない場合のみ
   - メニュー操作
   - ダイアログの確認
   - UIの視覚的確認が必要な場合

## UnityMCP使用時のルール
- 操作前にUnityの状態を確認する
- エラーが発生した場合は詳細を確認してから再試行
- 大量の操作を行う場合は段階的に実行

## Automation MCP使用時のルール（フォールバック）
- NEVER take full-screen screenshots
- ALWAYS restrict screenshots to the Unity window OR a specified region
- ALWAYS keep the Unity Editor window at a fixed position and size (x=0, y=0, width=1280, height=720)
- Prefer menu commands / keyboard shortcuts over pixel-clicking
- If an action fails twice, stop and report

## Error handling
- UnityMCPでエラー → 原因を確認し、可能なら修正して再試行
- それでも失敗 → Automation MCPにフォールバック
- Automation MCPでも失敗 → ユーザーに報告

## 開発フロー
1. スクリプトファイルの作成・編集はファイル操作ツールで行う
2. UnityMCPでシーンのセットアップを行う
3. 必要に応じてAutomation MCPで確認
