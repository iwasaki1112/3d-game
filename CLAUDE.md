# Claude Code Rules (Unity開発)

## Goal
UnityMCPを優先的に使用してUnityを操作する。UnityMCPで対応できない場合のみAutomation MCPを使用する。

## Tool Priority
1. **UnityMCP** (優先) - Unity Editor APIを直接呼び出せる操作
   - GameObjectの作成・編集・削除
   - コンポーネントの追加・設定
   - シーンの保存・読み込み
   - アセットの操作
   - メニュー実行（execute_menu_item）

2. **Automation MCP** (フォールバック) - UnityMCPで対応できない場合
   - ダイアログのOKボタンをクリック
   - UIの視覚的確認（スクリーンショット）

## ビルドコマンド
「iOSビルド」「ビルドして」「iPhoneで試したい」などと言われたら:
```
UnityMCPで execute_menu_item "Tools/高市総理ゲーム/6. iOS自動ビルド（Unity + Xcode）" を実行
```

その他のゲームセットアップコマンド:
- 「タイトルシーン作成」→ `Tools/高市総理ゲーム/1. タイトルシーン作成`
- 「ゲームシーン作成」→ `Tools/高市総理ゲーム/2. ゲームシーン作成`
- 「コインプレファブ作成」→ `Tools/高市総理ゲーム/3. コインプレファブ作成`
- 「TMPフォント修正」→ `Tools/高市総理ゲーム/4. TMPフォント修正（ビルド前に実行）`
- 「ビルド設定追加」→ `Tools/高市総理ゲーム/5. ビルド設定にシーン追加`
- 「Xcodeを開く」→ `Tools/高市総理ゲーム/7. Xcodeプロジェクトを開く`

## 開発フロー
1. スクリプトファイルの作成・編集はファイル操作ツールで行う
2. UnityMCPでシーンのセットアップ・メニュー実行を行う
3. ダイアログが表示されたらAutomation MCPでOKボタンをクリック
4. 必要に応じてAutomation MCPでスクリーンショット確認

## Error handling
- UnityMCPでエラー → 原因を確認し、可能なら修正して再試行
- ダイアログが表示された → Automation MCPでクリック
- それでも失敗 → ユーザーに報告
