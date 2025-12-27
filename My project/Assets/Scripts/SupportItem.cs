using UnityEngine;

/// <summary>
/// 支持率アイテム（Coinの代替名）
/// 取得すると支持率ポイントが上がる
/// </summary>
public class SupportItem : MonoBehaviour
{
    [Header("アイテム設定")]
    [SerializeField] private int pointValue = 10;
    [SerializeField] private float rotationSpeed = 100f;
    [SerializeField] private float bobSpeed = 2f;
    [SerializeField] private float bobHeight = 0.3f;
    [SerializeField] private Color itemColor = new Color(1f, 0.84f, 0f); // 金色

    [Header("エフェクト")]
    [SerializeField] private GameObject collectEffect;

    private Vector3 startPosition;
    private AudioSource audioSource;
    private Renderer itemRenderer;

    void Start()
    {
        startPosition = transform.position;
        audioSource = GetComponent<AudioSource>();
        itemRenderer = GetComponent<Renderer>();

        // 色を設定
        if (itemRenderer != null)
        {
            itemRenderer.material.color = itemColor;
        }
    }

    void Update()
    {
        // アイテムを回転させる
        transform.Rotate(Vector3.up, rotationSpeed * Time.deltaTime);

        // 上下にふわふわ動かす
        float newY = startPosition.y + Mathf.Sin(Time.time * bobSpeed) * bobHeight;
        transform.position = new Vector3(transform.position.x, newY, transform.position.z);
    }

    void OnTriggerEnter(Collider other)
    {
        if (other.CompareTag("Player"))
        {
            // スコアを加算
            if (GameManager.Instance != null)
            {
                GameManager.Instance.AddScore(pointValue);
            }

            // プレイヤーに通知
            PlayerController player = other.GetComponent<PlayerController>();
            if (player != null)
            {
                player.OnCoinCollected();
            }

            // エフェクトを生成
            if (collectEffect != null)
            {
                Instantiate(collectEffect, transform.position, Quaternion.identity);
            }

            // 効果音を再生（設定されている場合）
            if (audioSource != null && audioSource.clip != null)
            {
                AudioSource.PlayClipAtPoint(audioSource.clip, transform.position);
            }

            // アイテムを消す
            Destroy(gameObject);
        }
    }
}
