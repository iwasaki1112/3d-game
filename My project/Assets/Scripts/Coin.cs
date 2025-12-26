using UnityEngine;

/// <summary>
/// 支持率を表すコインアイテム
/// </summary>
public class Coin : MonoBehaviour
{
    [Header("コイン設定")]
    [SerializeField] private int pointValue = 10;
    [SerializeField] private float rotationSpeed = 100f;
    [SerializeField] private float bobSpeed = 2f;
    [SerializeField] private float bobHeight = 0.3f;
    
    private Vector3 startPosition;
    private AudioSource audioSource;
    
    void Start()
    {
        startPosition = transform.position;
        audioSource = GetComponent<AudioSource>();
    }
    
    void Update()
    {
        // コインを回転させる
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
            GameManager.Instance.AddScore(pointValue);
            
            // プレイヤーに通知
            PlayerController player = other.GetComponent<PlayerController>();
            if (player != null)
            {
                player.OnCoinCollected();
            }
            
            // 効果音を再生（設定されている場合）
            if (audioSource != null)
            {
                AudioSource.PlayClipAtPoint(audioSource.clip, transform.position);
            }
            
            // コインを消す
            Destroy(gameObject);
        }
    }
}
