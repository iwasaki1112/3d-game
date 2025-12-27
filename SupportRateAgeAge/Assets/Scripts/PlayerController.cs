using UnityEngine;

/// <summary>
/// TPSスタイルのプレイヤー操作コントローラー
/// モバイル対応（バーチャルジョイスティック + スワイプカメラ）
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
    [SerializeField] private float cameraSensitivity = 0.2f;
    [SerializeField] private float minVerticalAngle = -20f;
    [SerializeField] private float maxVerticalAngle = 60f;

    private CharacterController characterController;
    private Vector3 moveDirection;
    private float gravity = -9.81f;
    private float verticalVelocity;

    // モバイル入力用
    private Vector2 joystickInput;

    // カメラ回転用
    private float cameraYaw = 0f;
    private float cameraPitch = 20f;
    private Vector2 lastTouchPosition;
    private bool isCameraDragging = false;
    private int cameraTouchId = -1;

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
        HandleCameraInput();
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

    void HandleCameraInput()
    {
        // マウス入力（エディタ/PC用）
        if (Input.GetMouseButton(1)) // 右クリック
        {
            float mouseX = Input.GetAxis("Mouse X") * cameraSensitivity * 10f;
            float mouseY = Input.GetAxis("Mouse Y") * cameraSensitivity * 10f;

            cameraYaw += mouseX;
            cameraPitch -= mouseY;
            cameraPitch = Mathf.Clamp(cameraPitch, minVerticalAngle, maxVerticalAngle);
        }

        // タッチ入力（モバイル用）- 画面右半分でのスワイプ
        foreach (Touch touch in Input.touches)
        {
            // 画面右半分のタッチのみカメラ操作
            if (touch.position.x > Screen.width * 0.5f)
            {
                switch (touch.phase)
                {
                    case TouchPhase.Began:
                        if (!isCameraDragging)
                        {
                            isCameraDragging = true;
                            cameraTouchId = touch.fingerId;
                            lastTouchPosition = touch.position;
                        }
                        break;

                    case TouchPhase.Moved:
                        if (isCameraDragging && touch.fingerId == cameraTouchId)
                        {
                            Vector2 delta = touch.position - lastTouchPosition;
                            cameraYaw += delta.x * cameraSensitivity;
                            cameraPitch -= delta.y * cameraSensitivity;
                            cameraPitch = Mathf.Clamp(cameraPitch, minVerticalAngle, maxVerticalAngle);
                            lastTouchPosition = touch.position;
                        }
                        break;

                    case TouchPhase.Ended:
                    case TouchPhase.Canceled:
                        if (touch.fingerId == cameraTouchId)
                        {
                            isCameraDragging = false;
                            cameraTouchId = -1;
                        }
                        break;
                }
            }
        }
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
        // カメラの回転をクォータニオンに変換
        Quaternion cameraRotation = Quaternion.Euler(cameraPitch, cameraYaw, 0);

        // カメラのオフセット位置を計算
        Vector3 offset = cameraRotation * new Vector3(0, 0, -cameraDistance);
        offset.y += cameraHeight;

        // TPSカメラの位置を計算
        Vector3 targetPosition = transform.position + offset;
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
