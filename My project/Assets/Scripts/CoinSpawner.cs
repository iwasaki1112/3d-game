using UnityEngine;
using System.Collections.Generic;

/// <summary>
/// マップ上にコインを配置するスポナー
/// </summary>
public class CoinSpawner : MonoBehaviour
{
    [Header("スポーン設定")]
    [SerializeField] private GameObject coinPrefab;
    [SerializeField] private int numberOfCoins = 20;
    [SerializeField] private float spawnAreaWidth = 20f;
    [SerializeField] private float spawnAreaLength = 20f;
    [SerializeField] private float spawnHeight = 1f;
    [SerializeField] private float minDistanceBetweenCoins = 2f;
    
    [Header("デバッグ")]
    [SerializeField] private bool showSpawnArea = true;
    
    private List<Vector3> spawnedPositions = new List<Vector3>();
    
    void Start()
    {
        SpawnCoins();
    }
    
    void SpawnCoins()
    {
        if (coinPrefab == null)
        {
            Debug.LogError("Coin Prefabが設定されていません！");
            return;
        }
        
        int spawned = 0;
        int maxAttempts = numberOfCoins * 10;
        int attempts = 0;
        
        while (spawned < numberOfCoins && attempts < maxAttempts)
        {
            Vector3 randomPosition = GetRandomPosition();
            
            if (IsValidPosition(randomPosition))
            {
                GameObject coin = Instantiate(coinPrefab, randomPosition, Quaternion.identity, transform);
                spawnedPositions.Add(randomPosition);
                spawned++;
            }
            
            attempts++;
        }
        
        Debug.Log($"{spawned}個のコインをスポーンしました");
    }
    
    Vector3 GetRandomPosition()
    {
        float x = Random.Range(-spawnAreaWidth / 2, spawnAreaWidth / 2) + transform.position.x;
        float z = Random.Range(-spawnAreaLength / 2, spawnAreaLength / 2) + transform.position.z;
        
        // 地面の高さを取得（レイキャストで）
        float y = spawnHeight;
        RaycastHit hit;
        if (Physics.Raycast(new Vector3(x, 100f, z), Vector3.down, out hit, 200f))
        {
            y = hit.point.y + spawnHeight;
        }
        
        return new Vector3(x, y, z);
    }
    
    bool IsValidPosition(Vector3 position)
    {
        // 他のコインとの距離をチェック
        foreach (Vector3 existingPos in spawnedPositions)
        {
            if (Vector3.Distance(position, existingPos) < minDistanceBetweenCoins)
            {
                return false;
            }
        }
        
        // プレイヤーのスポーン位置（原点）から離れているかチェック
        if (Vector3.Distance(position, Vector3.zero) < 3f)
        {
            return false;
        }
        
        return true;
    }
    
    void OnDrawGizmos()
    {
        if (!showSpawnArea) return;
        
        Gizmos.color = new Color(0, 1, 0, 0.3f);
        Gizmos.DrawCube(
            transform.position + Vector3.up * spawnHeight,
            new Vector3(spawnAreaWidth, 0.5f, spawnAreaLength)
        );
        
        Gizmos.color = Color.green;
        Gizmos.DrawWireCube(
            transform.position + Vector3.up * spawnHeight,
            new Vector3(spawnAreaWidth, 0.5f, spawnAreaLength)
        );
    }
}
