// Force recompile v6 - Dynamic + Multi Atlas
using UnityEngine;
using UnityEditor;
using UnityEditor.SceneManagement;
using TMPro;
using System.Linq;
using System.Collections.Generic;

public class CreateJapaneseFont
{
    private const string FontPath = "Assets/Fonts/NotoSansJP-Medium.ttf";
    private const string OutputPath = "Assets/Fonts/NotoSansJP-Medium SDF.asset";

    [MenuItem("Tools/高市総理ゲーム/13. 日本語フォント自動生成")]
    public static void CreateFont()
    {
        Debug.Log("=== 日本語フォント自動生成開始 (Dynamic + Multi Atlas) ===");

        // フォント読み込み
        Font font = AssetDatabase.LoadAssetAtPath<Font>(FontPath);
        if (font == null)
        {
            Debug.LogError("フォントが見つかりません: " + FontPath);
            EditorUtility.DisplayDialog("エラー", "フォントが見つかりません: " + FontPath, "OK");
            return;
        }

        Debug.Log("ソースフォント読み込み成功: " + font.name);

        // 既存のFontAssetがあれば削除して新規作成
        var existing = AssetDatabase.LoadAssetAtPath<TMP_FontAsset>(OutputPath);
        if (existing != null)
        {
            AssetDatabase.DeleteAsset(OutputPath);
            Debug.Log("既存アセット削除");
            AssetDatabase.Refresh();
        }

        // 新規作成
        TMP_FontAsset jpAsset = TMP_FontAsset.CreateFontAsset(font);
        if (jpAsset == null)
        {
            Debug.LogError("TMP_FontAsset.CreateFontAsset が null を返しました");
            EditorUtility.DisplayDialog("エラー", "フォントアセットの作成に失敗しました。", "OK");
            return;
        }
        jpAsset.name = "NotoSansJP-Medium SDF";

        // Dynamic モード + Multi Atlas を有効化（重要：日本語でアトラスが溢れやすい）
        jpAsset.atlasPopulationMode = AtlasPopulationMode.Dynamic;
        jpAsset.isMultiAtlasTexturesEnabled = true;

        Debug.Log("Dynamic + Multi Atlas 設定完了");
        Debug.Log("  - atlasPopulationMode: " + jpAsset.atlasPopulationMode);
        Debug.Log("  - isMultiAtlasTexturesEnabled: " + jpAsset.isMultiAtlasTexturesEnabled);

        // アセットを保存
        AssetDatabase.CreateAsset(jpAsset, OutputPath);

        // アトラステクスチャとマテリアルをサブアセットとして追加
        if (jpAsset.atlasTextures != null)
        {
            foreach (var tex in jpAsset.atlasTextures)
            {
                if (tex != null && !AssetDatabase.Contains(tex))
                {
                    tex.name = jpAsset.name + " Atlas";
                    AssetDatabase.AddObjectToAsset(tex, jpAsset);
                }
            }
        }

        if (jpAsset.material != null && !AssetDatabase.Contains(jpAsset.material))
        {
            jpAsset.material.name = jpAsset.name + " Material";
            AssetDatabase.AddObjectToAsset(jpAsset.material, jpAsset);
        }

        EditorUtility.SetDirty(jpAsset);
        AssetDatabase.SaveAssets();
        AssetDatabase.Refresh();

        Debug.Log("フォントアセット保存完了: " + OutputPath);

        // 保存したアセットを再読み込み
        TMP_FontAsset savedFont = AssetDatabase.LoadAssetAtPath<TMP_FontAsset>(OutputPath);
        if (savedFont != null)
        {
            Debug.Log("保存確認:");
            Debug.Log("  - atlasPopulationMode: " + savedFont.atlasPopulationMode);
            Debug.Log("  - isMultiAtlasTexturesEnabled: " + savedFont.isMultiAtlasTexturesEnabled);
            Debug.Log("  - アトラス: " + (savedFont.atlasTexture != null ? savedFont.atlasTexture.width + "x" + savedFont.atlasTexture.height : "NULL"));

            // 全シーンにフォントを適用
            ApplyToAllScenes(savedFont);

            Debug.Log("=== 日本語フォント自動生成完了 ===");
            EditorUtility.DisplayDialog("完了",
                "日本語フォント（Dynamic + Multi Atlas）を設定しました。\n\n" +
                "日本語文字は実行時に自動でアトラスに追加されます。\n" +
                "6個のテキストコンポーネントに適用しました。",
                "OK");
        }
        else
        {
            Debug.LogError("保存後のフォント読み込みに失敗");
            EditorUtility.DisplayDialog("エラー", "フォントの保存確認に失敗しました。", "OK");
        }
    }

    static void ApplyToAllScenes(TMP_FontAsset font)
    {
        string[] scenes = { "Assets/Scenes/TitleScene.unity", "Assets/Scenes/GameScene.unity" };
        int count = 0;

        foreach (string scenePath in scenes)
        {
            if (!System.IO.File.Exists(Application.dataPath.Replace("Assets", "") + scenePath))
            {
                Debug.LogWarning("シーンなし: " + scenePath);
                continue;
            }

            Debug.Log("シーン処理: " + scenePath);
            var scene = EditorSceneManager.OpenScene(scenePath, OpenSceneMode.Single);

            foreach (var tmp in Object.FindObjectsByType<TextMeshProUGUI>(FindObjectsSortMode.None))
            {
                tmp.font = font;
                EditorUtility.SetDirty(tmp);
                count++;
            }

            foreach (var tmp in Object.FindObjectsByType<TextMeshPro>(FindObjectsSortMode.None))
            {
                tmp.font = font;
                EditorUtility.SetDirty(tmp);
                count++;
            }

            EditorSceneManager.MarkSceneDirty(scene);
            EditorSceneManager.SaveScene(scene);
        }

        Debug.Log("適用完了: " + count + "個のテキスト");
    }
}
