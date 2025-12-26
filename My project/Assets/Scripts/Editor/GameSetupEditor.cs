using UnityEngine;
using UnityEditor;
using UnityEngine.UI;
using TMPro;

/// <summary>
/// ゲームシーンを自動セットアップするエディターツール
/// </summary>
public class GameSetupEditor : EditorWindow
{
    [MenuItem("Tools/高市総理ゲーム/シーンセットアップ")]
    public static void SetupGameScene()
    {
        // 確認ダイアログ
        if (!EditorUtility.DisplayDialog("シーンセットアップ", 
            "現在のシーンにゲームオブジェクトを追加しますか？", "はい", "キャンセル"))
        {
            return;
        }

        CreateGround();
        CreatePlayer();
        CreateGameManager();
        CreateUI();
        CreateCoinSpawner();
        SetupLighting();
        
        Debug.Log("シーンセットアップ完了！");
        EditorUtility.DisplayDialog("完了", "シーンのセットアップが完了しました！\n\nCoin Prefabを作成してCoinSpawnerに設定してください。", "OK");
    }
    
    [MenuItem("Tools/高市総理ゲーム/コインプレファブ作成")]
    public static void CreateCoinPrefab()
    {
        // コインオブジェクト作成
        GameObject coin = GameObject.CreatePrimitive(PrimitiveType.Cylinder);
        coin.name = "Coin";
        coin.transform.localScale = new Vector3(0.5f, 0.05f, 0.5f);
        
        // マテリアル作成
        Material coinMaterial = new Material(Shader.Find("Universal Render Pipeline/Lit"));
        coinMaterial.color = new Color(1f, 0.84f, 0f); // ゴールド
        coinMaterial.SetFloat("_Smoothness", 0.8f);
        
        // マテリアル保存
        string materialPath = "Assets/Materials/CoinMaterial.mat";
        AssetDatabase.CreateAsset(coinMaterial, materialPath);
        
        coin.GetComponent<MeshRenderer>().material = coinMaterial;
        
        // コライダーをトリガーに（CylinderはMeshColliderを持つので、それを削除してSphereColliderを追加）
        DestroyImmediate(coin.GetComponent<MeshCollider>());
        SphereCollider sphereCollider = coin.AddComponent<SphereCollider>();
        sphereCollider.isTrigger = true;
        sphereCollider.radius = 0.5f;
        
        // Coinスクリプトを追加
        coin.AddComponent<Coin>();
        
        // プレファブとして保存
        string prefabPath = "Assets/Prefabs/Coin.prefab";
        PrefabUtility.SaveAsPrefabAsset(coin, prefabPath);
        
        // シーンから削除
        DestroyImmediate(coin);
        
        Debug.Log("コインプレファブを作成しました: " + prefabPath);
        
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
    }
    
    static void CreateGround()
    {
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
        player.name = "Player (Takaichi)";
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
        GameObject spawner = new GameObject("CoinSpawner");
        spawner.AddComponent<CoinSpawner>();
    }
    
    static void CreateUI()
    {
        // Canvas
        GameObject canvasObj = new GameObject("GameCanvas");
        Canvas canvas = canvasObj.AddComponent<Canvas>();
        canvas.renderMode = RenderMode.ScreenSpaceOverlay;
        canvasObj.AddComponent<CanvasScaler>();
        canvasObj.AddComponent<GraphicRaycaster>();
        
        // スコアテキスト
        CreateUIText("ScoreText", canvasObj.transform, 
            new Vector2(10, -10), new Vector2(300, 50), 
            TextAnchor.UpperLeft, "支持率ポイント: 0");
        
        // タイマーテキスト
        CreateUIText("TimerText", canvasObj.transform, 
            new Vector2(-10, -10), new Vector2(200, 50), 
            TextAnchor.UpperRight, "残り時間: 01:00");
        
        // 支持率テキスト
        CreateUIText("SupportRateText", canvasObj.transform, 
            new Vector2(0, -10), new Vector2(200, 50), 
            TextAnchor.UpperCenter, "支持率: 30%");
        
        // ゲームオーバーパネル
        CreateGameOverPanel(canvasObj.transform);
        
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
        Vector2 size, TextAnchor anchor, string defaultText)
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
        tmp.fontSize = 24;
        tmp.color = Color.white;
    }
    
    static void CreateGameOverPanel(Transform parent)
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
        panelImage.color = new Color(0, 0, 0, 0.7f);
        
        // タイトル
        CreateUIText("GameOverTitle", panel.transform, 
            new Vector2(0, -100), new Vector2(400, 60), 
            TextAnchor.UpperCenter, "ゲーム終了！");
        
        // 最終スコア
        GameObject finalScore = new GameObject("FinalScoreText");
        finalScore.transform.SetParent(panel.transform);
        RectTransform fsRT = finalScore.AddComponent<RectTransform>();
        fsRT.anchorMin = new Vector2(0.5f, 0.5f);
        fsRT.anchorMax = new Vector2(0.5f, 0.5f);
        fsRT.pivot = new Vector2(0.5f, 0.5f);
        fsRT.anchoredPosition = new Vector2(0, 50);
        fsRT.sizeDelta = new Vector2(400, 150);
        TextMeshProUGUI fsTMP = finalScore.AddComponent<TextMeshProUGUI>();
        fsTMP.text = "最終スコア: 0";
        fsTMP.fontSize = 28;
        fsTMP.color = Color.white;
        fsTMP.alignment = TextAlignmentOptions.Center;
        
        // メッセージ
        GameObject message = new GameObject("FinalMessageText");
        message.transform.SetParent(panel.transform);
        RectTransform msgRT = message.AddComponent<RectTransform>();
        msgRT.anchorMin = new Vector2(0.5f, 0.5f);
        msgRT.anchorMax = new Vector2(0.5f, 0.5f);
        msgRT.pivot = new Vector2(0.5f, 0.5f);
        msgRT.anchoredPosition = new Vector2(0, -50);
        msgRT.sizeDelta = new Vector2(500, 100);
        TextMeshProUGUI msgTMP = message.AddComponent<TextMeshProUGUI>();
        msgTMP.text = "";
        msgTMP.fontSize = 22;
        msgTMP.color = Color.yellow;
        msgTMP.alignment = TextAlignmentOptions.Center;
        
        // リスタートボタン
        GameObject button = new GameObject("RestartButton");
        button.transform.SetParent(panel.transform);
        RectTransform btnRT = button.AddComponent<RectTransform>();
        btnRT.anchorMin = new Vector2(0.5f, 0.5f);
        btnRT.anchorMax = new Vector2(0.5f, 0.5f);
        btnRT.pivot = new Vector2(0.5f, 0.5f);
        btnRT.anchoredPosition = new Vector2(0, -150);
        btnRT.sizeDelta = new Vector2(200, 50);
        
        Image btnImage = button.AddComponent<Image>();
        btnImage.color = new Color(0.2f, 0.6f, 0.2f);
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
        btTMP.fontSize = 24;
        btTMP.color = Color.white;
        btTMP.alignment = TextAlignmentOptions.Center;
        
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
        bgRT.anchoredPosition = new Vector2(50, 50);
        bgRT.sizeDelta = new Vector2(150, 150);
        
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
        handleRT.sizeDelta = new Vector2(60, 60);
        
        Image handleImage = handle.AddComponent<Image>();
        handleImage.color = new Color(1, 1, 1, 0.8f);
        
        // VirtualJoystickスクリプト
        VirtualJoystick vj = joystickBg.AddComponent<VirtualJoystick>();
        SerializedObject so = new SerializedObject(vj);
        so.FindProperty("joystickBackground").objectReferenceValue = bgRT;
        so.FindProperty("joystickHandle").objectReferenceValue = handleRT;
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
