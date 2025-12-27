# TextMeshPro 日本語フォント設定ガイド

## 問題の概要

TextMeshProで日本語テキストが「□□□」と表示される問題は、以下のいずれかが原因です：

1. **フォントアセットに日本語グリフが入っていない**
2. **Staticモードでアトラステクスチャが正しく保存されていない**
3. **フォールバック設定が効いていない**

## 解決方法：Dynamic + Multi Atlas モード

### なぜDynamicモードが必要か

- **Staticモード**: フォントアセット作成時にすべての文字をアトラスに焼き込む
  - 日本語の場合、数千文字が必要で巨大なアトラスになる
  - Unity 6ではプログラム的にStaticアトラスを正しく保存するのが困難

- **Dynamicモード**: 実行時に必要な文字を動的にアトラスに追加
  - 使用する文字だけがアトラスに追加される
  - Multi Atlasを有効にすれば、アトラスが溢れても自動的に追加アトラスが作成される

### 設定手順

#### 1. 日本語フォントファイルを用意

```
Assets/Fonts/NotoSansJP-Medium.ttf
```

推奨フォント：
- Noto Sans JP
- Source Han Sans
- M PLUS Rounded 1c

#### 2. TMP_FontAssetを作成（Dynamicモード）

```csharp
TMP_FontAsset fontAsset = TMP_FontAsset.CreateFontAsset(font);
fontAsset.atlasPopulationMode = AtlasPopulationMode.Dynamic;  // 重要！
fontAsset.isMultiAtlasTexturesEnabled = true;                 // 重要！
```

#### 3. アセットを保存

```csharp
AssetDatabase.CreateAsset(fontAsset, outputPath);

// アトラステクスチャとマテリアルをサブアセットとして追加
if (fontAsset.atlasTextures != null)
{
    foreach (var tex in fontAsset.atlasTextures)
    {
        if (tex != null && !AssetDatabase.Contains(tex))
        {
            AssetDatabase.AddObjectToAsset(tex, fontAsset);
        }
    }
}

if (fontAsset.material != null && !AssetDatabase.Contains(fontAsset.material))
{
    AssetDatabase.AddObjectToAsset(fontAsset.material, fontAsset);
}

EditorUtility.SetDirty(fontAsset);
AssetDatabase.SaveAssets();
```

## 自動セットアップスクリプト

プロジェクトには自動セットアップスクリプトがあります：

**メニュー**: `Tools > 高市総理ゲーム > 13. 日本語フォント自動生成`

このスクリプトは以下を実行します：
1. NotoSansJP-Medium.ttf から TMP_FontAsset を作成
2. Dynamic + Multi Atlas モードを設定
3. TitleScene と GameScene の全TextMeshProコンポーネントにフォントを適用
4. シーンを保存

## トラブルシューティング

### 日本語が全部□になる場合

1. フォントアセットが `AtlasPopulationMode.Dynamic` になっているか確認
2. `isMultiAtlasTexturesEnabled` が `true` になっているか確認
3. フォントアセットを選択して Inspector で確認

### 一部の文字だけ□になる場合

- フォントファイル自体にその文字が含まれていない可能性
- 別の日本語フォントを試す

### Editor では表示されるが実機で□になる場合

- ビルド時にフォントアセットが含まれているか確認
- `Resources` フォルダに入れるか、シーンから参照されているか確認

## 重要な設定値

| 設定項目 | 推奨値 | 説明 |
|---------|--------|------|
| atlasPopulationMode | Dynamic | 実行時に文字を動的追加 |
| isMultiAtlasTexturesEnabled | true | アトラス溢れ対策 |
| Atlas Resolution | 1024x1024以上 | 日本語には大きめを推奨 |
| Sampling Point Size | 90 | 品質とサイズのバランス |

## 参考リンク

- [TextMeshPro Documentation](https://docs.unity3d.com/Packages/com.unity.textmeshpro@latest)
- [Font Asset Creator](https://docs.unity3d.com/Packages/com.unity.textmeshpro@3.0/manual/FontAssetsCreator.html)
