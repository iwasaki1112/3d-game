using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.UI;
using TMPro;

/// <summary>
/// ゲーム全体を管理するマネージャー
/// スコア、時間制限、ゲーム状態を管理
/// </summary>
public class GameManager : MonoBehaviour
{
    public static GameManager Instance { get; private set; }
    
    [Header("ゲーム設定")]
    [SerializeField] private float gameDuration = 60f; // 制限時間（秒）
    [SerializeField] private int totalCoins = 20;
    
    [Header("UI参照")]
    [SerializeField] private TextMeshProUGUI scoreText;
    [SerializeField] private TextMeshProUGUI timerText;
    [SerializeField] private TextMeshProUGUI supportRateText;
    [SerializeField] private GameObject gameOverPanel;
    [SerializeField] private TextMeshProUGUI finalScoreText;
    [SerializeField] private TextMeshProUGUI finalMessageText;
    [SerializeField] private Button restartButton;
    
    private int currentScore;
    private int coinsCollected;
    private float remainingTime;
    private bool isGameOver;
    
    void Awake()
    {
        // シングルトンパターン
        if (Instance == null)
        {
            Instance = this;
        }
        else
        {
            Destroy(gameObject);
            return;
        }
    }
    
    void Start()
    {
        InitializeGame();
        
        if (restartButton != null)
        {
            restartButton.onClick.AddListener(RestartGame);
        }
    }
    
    void Update()
    {
        if (!isGameOver)
        {
            UpdateTimer();
        }
    }
    
    void InitializeGame()
    {
        currentScore = 0;
        coinsCollected = 0;
        remainingTime = gameDuration;
        isGameOver = false;
        
        if (gameOverPanel != null)
        {
            gameOverPanel.SetActive(false);
        }
        
        UpdateUI();
    }
    
    void UpdateTimer()
    {
        remainingTime -= Time.deltaTime;
        
        if (remainingTime <= 0)
        {
            remainingTime = 0;
            GameOver();
        }
        
        UpdateUI();
    }
    
    void UpdateUI()
    {
        if (scoreText != null)
        {
            scoreText.text = $"支持率ポイント: {currentScore}";
        }
        
        if (timerText != null)
        {
            int minutes = Mathf.FloorToInt(remainingTime / 60);
            int seconds = Mathf.FloorToInt(remainingTime % 60);
            timerText.text = $"残り時間: {minutes:00}:{seconds:00}";
        }
        
        if (supportRateText != null)
        {
            // 支持率をパーセンテージで表示
            float supportRate = CalculateSupportRate();
            supportRateText.text = $"支持率: {supportRate:F1}%";
        }
    }
    
    float CalculateSupportRate()
    {
        // 基本支持率30%から、コイン1個につき3%上昇
        float baseRate = 30f;
        float bonusRate = coinsCollected * 3f;
        return Mathf.Min(baseRate + bonusRate, 100f);
    }
    
    public void AddScore(int points)
    {
        if (isGameOver) return;
        
        currentScore += points;
        coinsCollected++;
        UpdateUI();
        
        // 全コイン収集でボーナス
        if (coinsCollected >= totalCoins)
        {
            AddBonus();
        }
    }
    
    void AddBonus()
    {
        // 全コイン収集ボーナス
        currentScore += 100;
        UpdateUI();
    }
    
    void GameOver()
    {
        isGameOver = true;
        
        if (gameOverPanel != null)
        {
            gameOverPanel.SetActive(true);
        }
        
        if (finalScoreText != null)
        {
            finalScoreText.text = $"最終スコア: {currentScore}\n" +
                                  $"取得コイン: {coinsCollected}/{totalCoins}\n" +
                                  $"最終支持率: {CalculateSupportRate():F1}%";
        }
        
        if (finalMessageText != null)
        {
            finalMessageText.text = GetResultMessage();
        }
        
        // プレイヤーの動きを止める
        Time.timeScale = 0f;
    }
    
    string GetResultMessage()
    {
        float supportRate = CalculateSupportRate();
        
        if (supportRate >= 70)
        {
            return "素晴らしい！圧倒的支持を獲得しました！\n日本の未来は明るい！";
        }
        else if (supportRate >= 50)
        {
            return "良い結果です！\n過半数の支持を獲得しました！";
        }
        else if (supportRate >= 40)
        {
            return "まずまずの結果です。\nもう少し頑張りましょう！";
        }
        else
        {
            return "もっと支持を集めましょう！\n再チャレンジ！";
        }
    }
    
    public void RestartGame()
    {
        Time.timeScale = 1f;
        SceneManager.LoadScene(SceneManager.GetActiveScene().name);
    }
    
    public bool IsGameOver()
    {
        return isGameOver;
    }
}
