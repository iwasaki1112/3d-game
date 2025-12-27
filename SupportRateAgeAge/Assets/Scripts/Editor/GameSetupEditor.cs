using UnityEngine;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine.UI;
using UnityEngine.SceneManagement;
using TMPro;

/// <summary>
/// ゲームシーンを自動セットアップするエディターツール
/// </summary>
public class GameSetupEditor : EditorWindow
{
    // TMPのデフォルトフォントアセット
    private static TMP_FontAsset GetDefaultFont()
    {
        // TMP Essential Resourcesからデフォルトフォントを探す
        string[] guids = AssetDatabase.FindAssets("LiberationSans SDF t:TMP_FontAsset");
        if (guids.Length > 0)
        {
            string path = AssetDatabase.GUIDToAssetPath(guids[0]);
            return AssetDatabase.LoadAssetAtPath<TMP_FontAsset>(path);
        }

        // 日本語フォントを探す
        guids = AssetDatabase.FindAssets("NotoSansCJKjp t:TMP_FontAsset");
        if (guids.Length > 0)
        {
            string path = AssetDatabase.GUIDToAssetPath(guids[0]);
            return AssetDatabase.LoadAssetAtPath<TMP_FontAsset>(path);
        }

        // いずれかのTMPフォントを探す
        guids = AssetDatabase.FindAssets("t:TMP_FontAsset");
        if (guids.Length > 0)
        {
            string path = AssetDatabase.GUIDToAssetPath(guids[0]);
            return AssetDatabase.LoadAssetAtPath<TMP_FontAsset>(path);
        }

        return null;
    }

    private static bool CheckTMPResources()
    {
        TMP_FontAsset font = GetDefaultFont();
        if (font == null)
        {
            bool importNow = EditorUtility.DisplayDialog(
                "TMP Essential Resources が必要です",
                "TextMeshProのフォントアセットが見つかりません。\n\n" +
                "Window → TextMeshPro → Import TMP Essential Resources\n" +
                "でインポートしてから再度実行してください。",
                "OK");
            return false;
        }
        return true;
    }
    [MenuItem("Tools/高市総理ゲーム/1. タイトルシーン作成")]
    public static void CreateTitleScene()
    {
        // TMPリソースチェック
        if (!CheckTMPResources()) return;
        TMP_FontAsset defaultFont = GetDefaultFont();

        // 新しいシーンを作成
        var newScene = EditorSceneManager.NewScene(NewSceneSetup.DefaultGameObjects, NewSceneMode.Single);

        // Canvasを作成
        GameObject canvasObj = new GameObject("TitleCanvas");
        Canvas canvas = canvasObj.AddComponent<Canvas>();
        canvas.renderMode = RenderMode.ScreenSpaceOverlay;
        CanvasScaler scaler = canvasObj.AddComponent<CanvasScaler>();
        scaler.uiScaleMode = CanvasScaler.ScaleMode.ScaleWithScreenSize;
        scaler.referenceResolution = new Vector2(1920, 1080);
        canvasObj.AddComponent<GraphicRaycaster>();

        // 背景
        GameObject bg = new GameObject("Background");
        bg.transform.SetParent(canvasObj.transform);
        RectTransform bgRT = bg.AddComponent<RectTransform>();
        bgRT.anchorMin = Vector2.zero;
        bgRT.anchorMax = Vector2.one;
        bgRT.offsetMin = Vector2.zero;
        bgRT.offsetMax = Vector2.zero;
        Image bgImage = bg.AddComponent<Image>();
        bgImage.color = new Color(0.1f, 0.2f, 0.4f); // 政治家っぽい紺色

        // タイトルテキスト
        GameObject titleObj = new GameObject("TitleText");
        titleObj.transform.SetParent(canvasObj.transform);
        RectTransform titleRT = titleObj.AddComponent<RectTransform>();
        titleRT.anchorMin = new Vector2(0.5f, 0.5f);
        titleRT.anchorMax = new Vector2(0.5f, 0.5f);
        titleRT.pivot = new Vector2(0.5f, 0.5f);
        titleRT.anchoredPosition = new Vector2(0, 150);
        titleRT.sizeDelta = new Vector2(800, 120);
        TextMeshProUGUI titleTMP = titleObj.AddComponent<TextMeshProUGUI>();
        titleTMP.text = "高市総理\n支持率コレクター";
        titleTMP.fontSize = 72;
        titleTMP.color = Color.white;
        titleTMP.alignment = TextAlignmentOptions.Center;
        titleTMP.fontStyle = FontStyles.Bold;
        if (defaultFont != null) titleTMP.font = defaultFont;

        // サブタイトル
        GameObject subtitleObj = new GameObject("SubtitleText");
        subtitleObj.transform.SetParent(canvasObj.transform);
        RectTransform subRT = subtitleObj.AddComponent<RectTransform>();
        subRT.anchorMin = new Vector2(0.5f, 0.5f);
        subRT.anchorMax = new Vector2(0.5f, 0.5f);
        subRT.pivot = new Vector2(0.5f, 0.5f);
        subRT.anchoredPosition = new Vector2(0, 30);
        subRT.sizeDelta = new Vector2(600, 50);
        TextMeshProUGUI subTMP = subtitleObj.AddComponent<TextMeshProUGUI>();
        subTMP.text = "制限時間内に支持率を集めよう！";
        subTMP.fontSize = 28;
        subTMP.color = new Color(1f, 0.9f, 0.5f);
        subTMP.alignment = TextAlignmentOptions.Center;
        if (defaultFont != null) subTMP.font = defaultFont;

        // スタートボタン
        GameObject startBtn = new GameObject("StartButton");
        startBtn.transform.SetParent(canvasObj.transform);
        RectTransform btnRT = startBtn.AddComponent<RectTransform>();
        btnRT.anchorMin = new Vector2(0.5f, 0.5f);
        btnRT.anchorMax = new Vector2(0.5f, 0.5f);
        btnRT.pivot = new Vector2(0.5f, 0.5f);
        btnRT.anchoredPosition = new Vector2(0, -100);
        btnRT.sizeDelta = new Vector2(300, 80);
        Image btnImage = startBtn.AddComponent<Image>();
        btnImage.color = new Color(0.8f, 0.2f, 0.2f); // 赤（日の丸っぽい）
        Button btn = startBtn.AddComponent<Button>();

        // ボタンテキスト
        GameObject btnTextObj = new GameObject("Text");
        btnTextObj.transform.SetParent(startBtn.transform);
        RectTransform btRT = btnTextObj.AddComponent<RectTransform>();
        btRT.anchorMin = Vector2.zero;
        btRT.anchorMax = Vector2.one;
        btRT.offsetMin = Vector2.zero;
        btRT.offsetMax = Vector2.zero;
        TextMeshProUGUI btTMP = btnTextObj.AddComponent<TextMeshProUGUI>();
        btTMP.text = "ゲームスタート";
        btTMP.fontSize = 36;
        btTMP.color = Color.white;
        btTMP.alignment = TextAlignmentOptions.Center;
        if (defaultFont != null) btTMP.font = defaultFont;

        // TitleScreenスクリプトを追加
        GameObject titleManager = new GameObject("TitleManager");
        TitleScreen ts = titleManager.AddComponent<TitleScreen>();
        SerializedObject so = new SerializedObject(ts);
        so.FindProperty("startButton").objectReferenceValue = btn;
        so.FindProperty("titleText").objectReferenceValue = titleTMP;
        so.FindProperty("subtitleText").objectReferenceValue = subTMP;
        so.FindProperty("gameSceneName").stringValue = "GameScene";
        so.ApplyModifiedProperties();

        // EventSystemを追加
        if (FindFirstObjectByType<UnityEngine.EventSystems.EventSystem>() == null)
        {
            GameObject eventSystem = new GameObject("EventSystem");
            eventSystem.AddComponent<UnityEngine.EventSystems.EventSystem>();
            eventSystem.AddComponent<UnityEngine.EventSystems.StandaloneInputModule>();
        }

        // シーンを保存
        string scenePath = "Assets/Scenes/TitleScene.unity";
        EditorSceneManager.SaveScene(newScene, scenePath);

        Debug.Log("タイトルシーンを作成しました: " + scenePath);
        EditorUtility.DisplayDialog("完了", "タイトルシーンを作成しました！\n\n次に「2. ゲームシーン作成」を実行してください。", "OK");
    }

    [MenuItem("Tools/高市総理ゲーム/2. ゲームシーン作成")]
    public static void CreateGameScene()
    {
        // TMPリソースチェック
        if (!CheckTMPResources()) return;

        // 新しいシーンを作成
        var newScene = EditorSceneManager.NewScene(NewSceneSetup.DefaultGameObjects, NewSceneMode.Single);

        SetupGameScene();

        // シーンを保存
        string scenePath = "Assets/Scenes/GameScene.unity";
        EditorSceneManager.SaveScene(newScene, scenePath);

        Debug.Log("ゲームシーンを作成しました: " + scenePath);
    }

    [MenuItem("Tools/高市総理ゲーム/3. コインプレファブ作成")]
    public static void CreateCoinPrefab()
    {
        // Prefabsフォルダが存在するか確認
        if (!AssetDatabase.IsValidFolder("Assets/Prefabs"))
        {
            AssetDatabase.CreateFolder("Assets", "Prefabs");
        }

        // Materialsフォルダが存在するか確認
        if (!AssetDatabase.IsValidFolder("Assets/Materials"))
        {
            AssetDatabase.CreateFolder("Assets", "Materials");
        }

        // コインオブジェクト作成
        GameObject coin = GameObject.CreatePrimitive(PrimitiveType.Cylinder);
        coin.name = "SupportItem";
        coin.transform.localScale = new Vector3(0.5f, 0.05f, 0.5f);

        // マテリアル作成
        Material coinMaterial = new Material(Shader.Find("Universal Render Pipeline/Lit"));
        coinMaterial.color = new Color(1f, 0.84f, 0f); // ゴールド
        coinMaterial.SetFloat("_Smoothness", 0.8f);

        // マテリアル保存
        string materialPath = "Assets/Materials/SupportItemMaterial.mat";
        AssetDatabase.CreateAsset(coinMaterial, materialPath);

        coin.GetComponent<MeshRenderer>().material = coinMaterial;

        // コライダーをトリガーに
        Collider existingCollider = coin.GetComponent<Collider>();
        if (existingCollider != null)
        {
            DestroyImmediate(existingCollider);
        }
        SphereCollider sphereCollider = coin.AddComponent<SphereCollider>();
        sphereCollider.isTrigger = true;
        sphereCollider.radius = 0.5f;

        // Coinスクリプトを追加
        coin.AddComponent<Coin>();

        // プレファブとして保存
        string prefabPath = "Assets/Prefabs/SupportItem.prefab";
        PrefabUtility.SaveAsPrefabAsset(coin, prefabPath);

        // シーンから削除
        DestroyImmediate(coin);

        Debug.Log("支持率アイテムプレファブを作成しました: " + prefabPath);

        // CoinSpawnerにプレファブを設定
        CoinSpawner spawner = FindFirstObjectByType<CoinSpawner>();
        if (spawner != null)
        {
            GameObject coinPrefab = AssetDatabase.LoadAssetAtPath<GameObject>(prefabPath);
            SerializedObject so = new SerializedObject(spawner);
            so.FindProperty("coinPrefab").objectReferenceValue = coinPrefab;
            so.ApplyModifiedProperties();
            Debug.Log("CoinSpawnerにプレファブを設定しました");
        }

        EditorUtility.DisplayDialog("完了", "支持率アイテムのプレファブを作成しました！\n\nこれでゲームの準備は完了です。", "OK");
    }

    [MenuItem("Tools/高市総理ゲーム/4. TMPフォント修正（ビルド前に実行）")]
    public static void FixTMPFonts()
    {
        TMP_FontAsset defaultFont = GetDefaultFont();
        if (defaultFont == null)
        {
            Debug.LogError("TMPフォントが見つかりません。Window → TextMeshPro → Import TMP Essential Resources でインポートしてください。");
            return;
        }

        // 現在のシーンのすべてのTMPテキストにフォントを設定
        TextMeshProUGUI[] tmpTexts = FindObjectsByType<TextMeshProUGUI>(FindObjectsSortMode.None);
        int fixedCount = 0;

        foreach (TextMeshProUGUI tmp in tmpTexts)
        {
            if (tmp.font == null)
            {
                tmp.font = defaultFont;
                EditorUtility.SetDirty(tmp);
                fixedCount++;
            }
        }

        // シーンを保存
        EditorSceneManager.SaveOpenScenes();

        Debug.Log($"TMPフォント修正完了: {fixedCount}個のテキストを修正しました");
        // ダイアログは表示しない（ログのみ）
    }

    [MenuItem("Tools/高市総理ゲーム/5. ビルド設定にシーン追加")]
    public static void AddScenesToBuild()
    {
        var scenes = new EditorBuildSettingsScene[]
        {
            new EditorBuildSettingsScene("Assets/Scenes/TitleScene.unity", true),
            new EditorBuildSettingsScene("Assets/Scenes/GameScene.unity", true)
        };

        EditorBuildSettings.scenes = scenes;

        Debug.Log("ビルド設定にシーンを追加しました");
        EditorUtility.DisplayDialog("完了", "ビルド設定にシーンを追加しました！\n\nFile > Build Settings で確認できます。", "OK");
    }

    static void SetupGameScene()
    {
        CreateGround();
        CreatePlayer();
        CreateGameManager();
        CreateUI();
        CreateCoinSpawner();
        SetupLighting();

        Debug.Log("ゲームシーンセットアップ完了！");
        EditorUtility.DisplayDialog("完了", "ゲームシーンのセットアップが完了しました！\n\n次に「3. コインプレファブ作成」を実行してください。", "OK");
    }

    static void CreateGround()
    {
        // Materialsフォルダが存在するか確認
        if (!AssetDatabase.IsValidFolder("Assets/Materials"))
        {
            AssetDatabase.CreateFolder("Assets", "Materials");
        }

        // 地面
        GameObject ground = GameObject.CreatePrimitive(PrimitiveType.Plane);
        ground.name = "Ground";
        ground.transform.localScale = new Vector3(3, 1, 3);

        // 地面マテリアル
        Material groundMaterial = new Material(Shader.Find("Universal Render Pipeline/Lit"));
        groundMaterial.color = new Color(0.3f, 0.6f, 0.3f); // 緑

        string materialPath = "Assets/Materials/GroundMaterial.mat";
        AssetDatabase.CreateAsset(groundMaterial, materialPath);

        ground.GetComponent<MeshRenderer>().material = groundMaterial;

        // 壁を追加（マップ境界）
        CreateWalls();
    }

    static void CreateWalls()
    {
        GameObject wallsParent = new GameObject("Walls");

        Material wallMaterial = new Material(Shader.Find("Universal Render Pipeline/Lit"));
        wallMaterial.color = new Color(0.5f, 0.5f, 0.5f);

        string materialPath = "Assets/Materials/WallMaterial.mat";
        AssetDatabase.CreateAsset(wallMaterial, materialPath);

        float wallHeight = 3f;
        float wallThickness = 0.5f;
        float mapSize = 15f;

        // 北壁
        CreateWall("Wall_North", new Vector3(0, wallHeight/2, mapSize),
            new Vector3(mapSize * 2, wallHeight, wallThickness), wallMaterial, wallsParent.transform);

        // 南壁
        CreateWall("Wall_South", new Vector3(0, wallHeight/2, -mapSize),
            new Vector3(mapSize * 2, wallHeight, wallThickness), wallMaterial, wallsParent.transform);

        // 東壁
        CreateWall("Wall_East", new Vector3(mapSize, wallHeight/2, 0),
            new Vector3(wallThickness, wallHeight, mapSize * 2), wallMaterial, wallsParent.transform);

        // 西壁
        CreateWall("Wall_West", new Vector3(-mapSize, wallHeight/2, 0),
            new Vector3(wallThickness, wallHeight, mapSize * 2), wallMaterial, wallsParent.transform);
    }

    static void CreateWall(string name, Vector3 position, Vector3 scale, Material material, Transform parent)
    {
        GameObject wall = GameObject.CreatePrimitive(PrimitiveType.Cube);
        wall.name = name;
        wall.transform.position = position;
        wall.transform.localScale = scale;
        wall.transform.parent = parent;
        wall.GetComponent<MeshRenderer>().material = material;
    }

    static void CreatePlayer()
    {
        // プレイヤーオブジェクト
        GameObject player = GameObject.CreatePrimitive(PrimitiveType.Capsule);
        player.name = "Player_Takaichi";
        player.transform.position = new Vector3(0, 1, 0);
        player.tag = "Player";

        // コライダーを削除してCharacterControllerを追加
        DestroyImmediate(player.GetComponent<CapsuleCollider>());
        CharacterController cc = player.AddComponent<CharacterController>();
        cc.center = new Vector3(0, 0, 0);
        cc.height = 2f;
        cc.radius = 0.5f;

        // プレイヤーマテリアル
        Material playerMaterial = new Material(Shader.Find("Universal Render Pipeline/Lit"));
        playerMaterial.color = new Color(0.2f, 0.4f, 0.8f); // 青（政治家っぽい色）

        string materialPath = "Assets/Materials/PlayerMaterial.mat";
        AssetDatabase.CreateAsset(playerMaterial, materialPath);

        player.GetComponent<MeshRenderer>().material = playerMaterial;

        // PlayerControllerスクリプトを追加
        player.AddComponent<PlayerController>();

        // カメラ設定
        Camera.main.transform.position = new Vector3(0, 5, -7);
        Camera.main.transform.LookAt(player.transform);
    }

    static void CreateGameManager()
    {
        GameObject gmObject = new GameObject("GameManager");
        gmObject.AddComponent<GameManager>();
    }

    static void CreateCoinSpawner()
    {
        GameObject spawner = new GameObject("SupportItemSpawner");
        spawner.AddComponent<CoinSpawner>();
    }

    static void CreateUI()
    {
        // フォントを取得
        TMP_FontAsset defaultFont = GetDefaultFont();

        // Canvas
        GameObject canvasObj = new GameObject("GameCanvas");
        Canvas canvas = canvasObj.AddComponent<Canvas>();
        canvas.renderMode = RenderMode.ScreenSpaceOverlay;
        CanvasScaler scaler = canvasObj.AddComponent<CanvasScaler>();
        scaler.uiScaleMode = CanvasScaler.ScaleMode.ScaleWithScreenSize;
        scaler.referenceResolution = new Vector2(1920, 1080);
        canvasObj.AddComponent<GraphicRaycaster>();

        // EventSystemを追加
        if (FindFirstObjectByType<UnityEngine.EventSystems.EventSystem>() == null)
        {
            GameObject eventSystem = new GameObject("EventSystem");
            eventSystem.AddComponent<UnityEngine.EventSystems.EventSystem>();
            eventSystem.AddComponent<UnityEngine.EventSystems.StandaloneInputModule>();
        }

        // スコアテキスト
        CreateUIText("ScoreText", canvasObj.transform,
            new Vector2(20, -20), new Vector2(350, 50),
            TextAnchor.UpperLeft, "支持率ポイント: 0", 28, defaultFont);

        // タイマーテキスト
        CreateUIText("TimerText", canvasObj.transform,
            new Vector2(-20, -20), new Vector2(220, 50),
            TextAnchor.UpperRight, "残り時間: 01:00", 28, defaultFont);

        // 支持率テキスト
        CreateUIText("SupportRateText", canvasObj.transform,
            new Vector2(0, -20), new Vector2(250, 50),
            TextAnchor.UpperCenter, "支持率: 30%", 32, defaultFont);

        // ゲームオーバーパネル
        CreateGameOverPanel(canvasObj.transform, defaultFont);

        // バーチャルジョイスティック
        CreateVirtualJoystick(canvasObj.transform);

        // GameManagerにUI参照を設定
        GameManager gm = FindFirstObjectByType<GameManager>();
        if (gm != null)
        {
            SerializedObject so = new SerializedObject(gm);
            so.FindProperty("scoreText").objectReferenceValue =
                GameObject.Find("ScoreText")?.GetComponent<TextMeshProUGUI>();
            so.FindProperty("timerText").objectReferenceValue =
                GameObject.Find("TimerText")?.GetComponent<TextMeshProUGUI>();
            so.FindProperty("supportRateText").objectReferenceValue =
                GameObject.Find("SupportRateText")?.GetComponent<TextMeshProUGUI>();
            so.FindProperty("gameOverPanel").objectReferenceValue =
                GameObject.Find("GameOverPanel");
            so.FindProperty("finalScoreText").objectReferenceValue =
                GameObject.Find("FinalScoreText")?.GetComponent<TextMeshProUGUI>();
            so.FindProperty("finalMessageText").objectReferenceValue =
                GameObject.Find("FinalMessageText")?.GetComponent<TextMeshProUGUI>();
            so.FindProperty("restartButton").objectReferenceValue =
                GameObject.Find("RestartButton")?.GetComponent<Button>();
            so.ApplyModifiedProperties();
        }
    }

    static void CreateUIText(string name, Transform parent, Vector2 anchoredPos,
        Vector2 size, TextAnchor anchor, string defaultText, int fontSize = 24, TMP_FontAsset font = null)
    {
        GameObject textObj = new GameObject(name);
        textObj.transform.SetParent(parent);

        RectTransform rt = textObj.AddComponent<RectTransform>();

        // アンカー設定
        if (anchor == TextAnchor.UpperLeft)
        {
            rt.anchorMin = new Vector2(0, 1);
            rt.anchorMax = new Vector2(0, 1);
            rt.pivot = new Vector2(0, 1);
        }
        else if (anchor == TextAnchor.UpperRight)
        {
            rt.anchorMin = new Vector2(1, 1);
            rt.anchorMax = new Vector2(1, 1);
            rt.pivot = new Vector2(1, 1);
        }
        else
        {
            rt.anchorMin = new Vector2(0.5f, 1);
            rt.anchorMax = new Vector2(0.5f, 1);
            rt.pivot = new Vector2(0.5f, 1);
        }

        rt.anchoredPosition = anchoredPos;
        rt.sizeDelta = size;

        TextMeshProUGUI tmp = textObj.AddComponent<TextMeshProUGUI>();
        tmp.text = defaultText;
        tmp.fontSize = fontSize;
        tmp.color = Color.white;
        if (font != null) tmp.font = font;

        // 背景を追加して見やすくする
        GameObject bgObj = new GameObject("Background");
        bgObj.transform.SetParent(textObj.transform);
        bgObj.transform.SetAsFirstSibling();
        RectTransform bgRT = bgObj.AddComponent<RectTransform>();
        bgRT.anchorMin = Vector2.zero;
        bgRT.anchorMax = Vector2.one;
        bgRT.offsetMin = new Vector2(-10, -5);
        bgRT.offsetMax = new Vector2(10, 5);
        Image bgImage = bgObj.AddComponent<Image>();
        bgImage.color = new Color(0, 0, 0, 0.5f);
    }

    static void CreateGameOverPanel(Transform parent, TMP_FontAsset font = null)
    {
        // パネル背景
        GameObject panel = new GameObject("GameOverPanel");
        panel.transform.SetParent(parent);

        RectTransform panelRT = panel.AddComponent<RectTransform>();
        panelRT.anchorMin = Vector2.zero;
        panelRT.anchorMax = Vector2.one;
        panelRT.offsetMin = Vector2.zero;
        panelRT.offsetMax = Vector2.zero;

        Image panelImage = panel.AddComponent<Image>();
        panelImage.color = new Color(0, 0, 0, 0.8f);

        // タイトル
        GameObject titleObj = new GameObject("GameOverTitle");
        titleObj.transform.SetParent(panel.transform);
        RectTransform titleRT = titleObj.AddComponent<RectTransform>();
        titleRT.anchorMin = new Vector2(0.5f, 0.5f);
        titleRT.anchorMax = new Vector2(0.5f, 0.5f);
        titleRT.pivot = new Vector2(0.5f, 0.5f);
        titleRT.anchoredPosition = new Vector2(0, 180);
        titleRT.sizeDelta = new Vector2(500, 80);
        TextMeshProUGUI titleTMP = titleObj.AddComponent<TextMeshProUGUI>();
        titleTMP.text = "タイムアップ！";
        titleTMP.fontSize = 56;
        titleTMP.color = Color.white;
        titleTMP.alignment = TextAlignmentOptions.Center;
        titleTMP.fontStyle = FontStyles.Bold;
        if (font != null) titleTMP.font = font;

        // 最終スコア
        GameObject finalScore = new GameObject("FinalScoreText");
        finalScore.transform.SetParent(panel.transform);
        RectTransform fsRT = finalScore.AddComponent<RectTransform>();
        fsRT.anchorMin = new Vector2(0.5f, 0.5f);
        fsRT.anchorMax = new Vector2(0.5f, 0.5f);
        fsRT.pivot = new Vector2(0.5f, 0.5f);
        fsRT.anchoredPosition = new Vector2(0, 60);
        fsRT.sizeDelta = new Vector2(500, 150);
        TextMeshProUGUI fsTMP = finalScore.AddComponent<TextMeshProUGUI>();
        fsTMP.text = "最終スコア: 0";
        fsTMP.fontSize = 32;
        fsTMP.color = Color.white;
        fsTMP.alignment = TextAlignmentOptions.Center;
        if (font != null) fsTMP.font = font;

        // メッセージ
        GameObject message = new GameObject("FinalMessageText");
        message.transform.SetParent(panel.transform);
        RectTransform msgRT = message.AddComponent<RectTransform>();
        msgRT.anchorMin = new Vector2(0.5f, 0.5f);
        msgRT.anchorMax = new Vector2(0.5f, 0.5f);
        msgRT.pivot = new Vector2(0.5f, 0.5f);
        msgRT.anchoredPosition = new Vector2(0, -50);
        msgRT.sizeDelta = new Vector2(600, 100);
        TextMeshProUGUI msgTMP = message.AddComponent<TextMeshProUGUI>();
        msgTMP.text = "";
        msgTMP.fontSize = 26;
        msgTMP.color = new Color(1f, 0.9f, 0.5f);
        msgTMP.alignment = TextAlignmentOptions.Center;
        if (font != null) msgTMP.font = font;

        // リスタートボタン
        GameObject button = new GameObject("RestartButton");
        button.transform.SetParent(panel.transform);
        RectTransform btnRT = button.AddComponent<RectTransform>();
        btnRT.anchorMin = new Vector2(0.5f, 0.5f);
        btnRT.anchorMax = new Vector2(0.5f, 0.5f);
        btnRT.pivot = new Vector2(0.5f, 0.5f);
        btnRT.anchoredPosition = new Vector2(0, -160);
        btnRT.sizeDelta = new Vector2(280, 70);

        Image btnImage = button.AddComponent<Image>();
        btnImage.color = new Color(0.8f, 0.2f, 0.2f);
        button.AddComponent<Button>();

        // ボタンテキスト
        GameObject btnText = new GameObject("Text");
        btnText.transform.SetParent(button.transform);
        RectTransform btRT = btnText.AddComponent<RectTransform>();
        btRT.anchorMin = Vector2.zero;
        btRT.anchorMax = Vector2.one;
        btRT.offsetMin = Vector2.zero;
        btRT.offsetMax = Vector2.zero;
        TextMeshProUGUI btTMP = btnText.AddComponent<TextMeshProUGUI>();
        btTMP.text = "もう一度プレイ";
        btTMP.fontSize = 32;
        btTMP.color = Color.white;
        btTMP.alignment = TextAlignmentOptions.Center;
        if (font != null) btTMP.font = font;

        // パネルを非表示に
        panel.SetActive(false);
    }

    static void CreateVirtualJoystick(Transform parent)
    {
        // ジョイスティック背景
        GameObject joystickBg = new GameObject("JoystickBackground");
        joystickBg.transform.SetParent(parent);

        RectTransform bgRT = joystickBg.AddComponent<RectTransform>();
        bgRT.anchorMin = new Vector2(0, 0);
        bgRT.anchorMax = new Vector2(0, 0);
        bgRT.pivot = new Vector2(0, 0);
        bgRT.anchoredPosition = new Vector2(80, 80);
        bgRT.sizeDelta = new Vector2(200, 200);

        Image bgImage = joystickBg.AddComponent<Image>();
        bgImage.color = new Color(1, 1, 1, 0.3f);

        // ジョイスティックハンドル
        GameObject handle = new GameObject("JoystickHandle");
        handle.transform.SetParent(joystickBg.transform);

        RectTransform handleRT = handle.AddComponent<RectTransform>();
        handleRT.anchorMin = new Vector2(0.5f, 0.5f);
        handleRT.anchorMax = new Vector2(0.5f, 0.5f);
        handleRT.pivot = new Vector2(0.5f, 0.5f);
        handleRT.anchoredPosition = Vector2.zero;
        handleRT.sizeDelta = new Vector2(80, 80);

        Image handleImage = handle.AddComponent<Image>();
        handleImage.color = new Color(1, 1, 1, 0.8f);

        // VirtualJoystickスクリプト
        VirtualJoystick vj = joystickBg.AddComponent<VirtualJoystick>();
        SerializedObject so = new SerializedObject(vj);
        so.FindProperty("joystickBackground").objectReferenceValue = bgRT;
        so.FindProperty("joystickHandle").objectReferenceValue = handleRT;
        so.FindProperty("handleRange").floatValue = 80f;
        so.ApplyModifiedProperties();
    }

    static void SetupLighting()
    {
        // 既存のDirectional Lightを調整
        Light[] lights = FindObjectsByType<Light>(FindObjectsSortMode.None);
        foreach (Light light in lights)
        {
            if (light.type == LightType.Directional)
            {
                light.intensity = 1.2f;
                light.transform.rotation = Quaternion.Euler(50, -30, 0);
                return;
            }
        }

        // なければ作成
        GameObject lightObj = new GameObject("Directional Light");
        Light newLight = lightObj.AddComponent<Light>();
        newLight.type = LightType.Directional;
        newLight.intensity = 1.2f;
        lightObj.transform.rotation = Quaternion.Euler(50, -30, 0);
    }
}
