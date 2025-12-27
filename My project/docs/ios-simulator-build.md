# iOS Simulator ビルド設定

## 使用するシミュレーター

**iPhone 16 Pro (iOS 18.2)** を使用する

シミュレーター ID: `2CDDC117-50D0-41E5-B9D7-0B5DFA00C76A`

## ビルド手順

### 1. Unity からエクスポート

**メニュー**: `Tools > 高市総理ゲーム > 12. iOSシミュレーター用ビルド＆実行`

または手動で：
1. `File > Build Settings`
2. Platform: iOS
3. Run in Xcode as: Simulator SDK
4. Build

### 2. Xcode でビルド

```bash
cd "/Users/iwasakishungo/Git/github.com/iwasaki1112/3d-game/My project/Builds/iOS-Simulator"

xcodebuild -project Unity-iPhone.xcodeproj \
    -scheme Unity-iPhone \
    -configuration Debug \
    -destination "id=2CDDC117-50D0-41E5-B9D7-0B5DFA00C76A" \
    -derivedDataPath ./DerivedData \
    CODE_SIGN_IDENTITY=- \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO
```

### 3. シミュレーターにインストール＆起動

```bash
# シミュレーターを起動
xcrun simctl boot 2CDDC117-50D0-41E5-B9D7-0B5DFA00C76A

# アプリをインストール
xcrun simctl install 2CDDC117-50D0-41E5-B9D7-0B5DFA00C76A \
    "./DerivedData/Build/Products/Debug-iphonesimulator/Myproject.app"

# アプリを起動
xcrun simctl launch 2CDDC117-50D0-41E5-B9D7-0B5DFA00C76A \
    "com.Unity-Technologies.com.unity.template.urp-blank"

# Simulator アプリを開く
open -a Simulator
```

## 利用可能なシミュレーター一覧

よく使うシミュレーター：

| デバイス | iOS バージョン | ID |
|---------|---------------|-----|
| iPhone 16 Pro | 18.2 | 2CDDC117-50D0-41E5-B9D7-0B5DFA00C76A |
| iPhone 16 Pro | 18.5 | 82F18302-C343-49FA-BF36-BB4BF686C9FB |
| iPhone 16 Pro Max | 18.2 | E837D5C4-B1D7-4FC8-B879-554D5A1C9422 |
| iPhone 15 Pro | 17.5 | 89F63E36-F55A-465A-8FE9-D76553ECEEBE |

一覧を取得するコマンド：
```bash
xcrun simctl list devices available
```

## トラブルシューティング

### シミュレーターが見つからない場合

```bash
# 最新のシミュレーターランタイムをインストール
xcodebuild -downloadPlatform iOS
```

### アプリが起動しない場合

1. Bundle ID を確認：
```bash
/usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" \
    "./DerivedData/Build/Products/Debug-iphonesimulator/Myproject.app/Info.plist"
```

2. シミュレーターをリセット：
```bash
xcrun simctl shutdown 2CDDC117-50D0-41E5-B9D7-0B5DFA00C76A
xcrun simctl erase 2CDDC117-50D0-41E5-B9D7-0B5DFA00C76A
xcrun simctl boot 2CDDC117-50D0-41E5-B9D7-0B5DFA00C76A
```

## BuildAutomation.cs の設定

`Assets/Scripts/Editor/BuildAutomation.cs` でシミュレーター名を変更する場合：

```csharp
// Line 448 付近
string simulatorName = "iPhone 16 Pro";
```
