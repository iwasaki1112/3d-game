using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.UI;
using TMPro;

/// <summary>
/// タイトル画面の管理
/// </summary>
public class TitleScreen : MonoBehaviour
{
    [Header("UI参照")]
    [SerializeField] private Button startButton;
    [SerializeField] private TextMeshProUGUI titleText;
    [SerializeField] private TextMeshProUGUI subtitleText;

    [Header("シーン設定")]
    [SerializeField] private string gameSceneName = "GameScene";

    void Start()
    {
        if (startButton != null)
        {
            startButton.onClick.AddListener(StartGame);
        }

        // タイトルアニメーション
        if (titleText != null)
        {
            StartCoroutine(AnimateTitle());
        }
    }

    System.Collections.IEnumerator AnimateTitle()
    {
        while (true)
        {
            // 簡単な脈動アニメーション
            float scale = 1f + Mathf.Sin(Time.time * 2f) * 0.05f;
            titleText.transform.localScale = Vector3.one * scale;
            yield return null;
        }
    }

    public void StartGame()
    {
        SceneManager.LoadScene(gameSceneName);
    }
}
