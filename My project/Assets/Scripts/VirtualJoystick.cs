using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;

/// <summary>
/// モバイル用バーチャルジョイスティック
/// </summary>
public class VirtualJoystick : MonoBehaviour, IDragHandler, IPointerDownHandler, IPointerUpHandler
{
    [Header("ジョイスティック設定")]
    [SerializeField] private RectTransform joystickBackground;
    [SerializeField] private RectTransform joystickHandle;
    [SerializeField] private float handleRange = 50f;
    
    [Header("プレイヤー参照")]
    [SerializeField] private PlayerController playerController;
    
    private Vector2 inputVector;
    private Vector2 joystickCenter;
    
    void Start()
    {
        joystickCenter = joystickBackground.position;
        
        if (playerController == null)
        {
            playerController = FindFirstObjectByType<PlayerController>();
        }
    }
    
    public void OnPointerDown(PointerEventData eventData)
    {
        OnDrag(eventData);
    }
    
    public void OnDrag(PointerEventData eventData)
    {
        Vector2 direction = eventData.position - joystickCenter;
        
        // ハンドルの移動範囲を制限
        inputVector = direction.magnitude > handleRange 
            ? direction.normalized 
            : direction / handleRange;
        
        // ハンドルを移動
        joystickHandle.anchoredPosition = inputVector * handleRange;
        
        // プレイヤーに入力を送信
        if (playerController != null)
        {
            playerController.SetJoystickInput(inputVector);
        }
    }
    
    public void OnPointerUp(PointerEventData eventData)
    {
        inputVector = Vector2.zero;
        joystickHandle.anchoredPosition = Vector2.zero;
        
        if (playerController != null)
        {
            playerController.SetJoystickInput(Vector2.zero);
        }
    }
    
    public Vector2 GetInput()
    {
        return inputVector;
    }
}
