using UnityEngine;

/// <summary>
/// TPSスタイルのプレイヤー操作コントローラー
/// モバイル対応（バーチャルジョイスティック）
/// </summary>
public class PlayerController : MonoBehaviour
{
    [Header("移動設定")]
    [SerializeField] private float moveSpeed = 5f;
    [SerializeField] private float rotationSpeed = 10f;
    
    [Header("カメラ設定")]
    [SerializeField] private Transform cameraTransform;
    [SerializeField] private float cameraDistance = 5f;
    [SerializeField] private float cameraHeight = 3f;
    [SerializeField] private float cameraSmoothSpeed = 5f;
    
    private CharacterController characterController;
    private Vector3 moveDirection;
    private float gravity = -9.81f;
    private float verticalVelocity;
    
    // モバイル入力用
    private Vector2 joystickInput;
    
    void Start()
    {
        characterController = GetComponent<CharacterController>();
        
        if (cameraTransform == null)
        {
            cameraTransform = Camera.main.transform;
        }
    }
    
    void Update()
    {
        HandleInput();
        HandleMovement();
        HandleCameraFollow();
    }
    
    void HandleInput()
    {
        // キーボード入力（デバッグ用）
        float horizontal = Input.GetAxis("Horizontal");
        float vertical = Input.GetAxis("Vertical");
        
        // モバイルジョイスティック入力がある場合はそちらを優先
        if (joystickInput.magnitude > 0.1f)
        {
            horizontal = joystickInput.x;
            vertical = joystickInput.y;
        }
        
        // カメラの向きを基準にした移動方向を計算
        Vector3 forward = cameraTransform.forward;
        Vector3 right = cameraTransform.right;
        forward.y = 0;
        right.y = 0;
        forward.Normalize();
        right.Normalize();
        
        moveDirection = (forward * vertical + right * horizontal).normalized;
    }
    
    void HandleMovement()
    {
        // 重力処理
        if (characterController.isGrounded)
        {
            verticalVelocity = -2f;
        }
        else
        {
            verticalVelocity += gravity * Time.deltaTime;
        }
        
        // 移動
        Vector3 velocity = moveDirection * moveSpeed;
        velocity.y = verticalVelocity;
        characterController.Move(velocity * Time.deltaTime);
        
        // キャラクターの向きを移動方向に合わせる
        if (moveDirection.magnitude > 0.1f)
        {
            Quaternion targetRotation = Quaternion.LookRotation(moveDirection);
            transform.rotation = Quaternion.Slerp(transform.rotation, targetRotation, rotationSpeed * Time.deltaTime);
        }
    }
    
    void HandleCameraFollow()
    {
        // TPSカメラの位置を計算
        Vector3 targetPosition = transform.position - transform.forward * cameraDistance + Vector3.up * cameraHeight;
        cameraTransform.position = Vector3.Lerp(cameraTransform.position, targetPosition, cameraSmoothSpeed * Time.deltaTime);
        cameraTransform.LookAt(transform.position + Vector3.up * 1.5f);
    }
    
    /// <summary>
    /// モバイルジョイスティックからの入力を受け取る
    /// </summary>
    public void SetJoystickInput(Vector2 input)
    {
        joystickInput = input;
    }
    
    /// <summary>
    /// コイン取得時の効果
    /// </summary>
    public void OnCoinCollected()
    {
        // 簡単なエフェクト（パーティクルなど追加可能）
    }
}
