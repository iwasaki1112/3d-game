#!/bin/bash
#
# iOS 自動ビルドスクリプト
# Unity ビルド → Xcode ビルド → 実機デプロイ
#

set -e

# 設定
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
UNITY_PROJECT="$PROJECT_ROOT/My project"
BUILD_PATH="$PROJECT_ROOT/Builds/iOS"
UNITY_APP="/Applications/Unity/Hub/Editor/6000.0.32f1/Unity.app/Contents/MacOS/Unity"

# Unity のパスを自動検出
if [ ! -f "$UNITY_APP" ]; then
    # Unity Hub でインストールされたバージョンを探す
    UNITY_APP=$(find /Applications/Unity/Hub/Editor -name "Unity" -type f 2>/dev/null | head -1)
fi

if [ ! -f "$UNITY_APP" ]; then
    echo "エラー: Unity が見つかりません"
    echo "Unity Hub から Unity をインストールしてください"
    exit 1
fi

echo "========================================"
echo "  高市総理ゲーム iOS 自動ビルド"
echo "========================================"
echo ""
echo "Unity: $UNITY_APP"
echo "プロジェクト: $UNITY_PROJECT"
echo "出力先: $BUILD_PATH"
echo ""

# ビルドフォルダ作成
mkdir -p "$BUILD_PATH"

# Unity バッチモードでビルド
echo "=== Step 1: Unity ビルド ==="
"$UNITY_APP" \
    -quit \
    -batchmode \
    -projectPath "$UNITY_PROJECT" \
    -executeMethod BuildAutomation.BuildiOSCommandLine \
    -logFile "$BUILD_PATH/unity_build.log" \
    -buildTarget iOS

BUILD_RESULT=$?

if [ $BUILD_RESULT -ne 0 ]; then
    echo "Unity ビルドに失敗しました"
    echo "ログ: $BUILD_PATH/unity_build.log"
    cat "$BUILD_PATH/unity_build.log" | tail -50
    exit 1
fi

echo "Unity ビルド完了"

# Xcode ビルド
echo ""
echo "=== Step 2: Xcode ビルド ==="
cd "$BUILD_PATH"

if [ ! -d "Unity-iPhone.xcodeproj" ]; then
    echo "エラー: Xcode プロジェクトが見つかりません"
    exit 1
fi

# ビルド（署名なし）
xcodebuild \
    -project Unity-iPhone.xcodeproj \
    -scheme Unity-iPhone \
    -configuration Debug \
    -destination 'generic/platform=iOS' \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    build 2>&1 | xcpretty || true

echo ""
echo "========================================"
echo "  ビルド完了！"
echo "========================================"
echo ""
echo "Xcode プロジェクトを開きます..."
open "$BUILD_PATH/Unity-iPhone.xcodeproj"
echo ""
echo "手順:"
echo "1. Signing & Capabilities で Team を選択"
echo "2. 接続した iPhone を選択"
echo "3. ▶️ ボタンで実行"
echo ""
