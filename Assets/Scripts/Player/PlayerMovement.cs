using System;
using Unity.Cinemachine;
using Unity.VisualScripting;
using UnityEngine;
using UnityEngine.InputSystem;

public class PlayerMovement : MonoBehaviour
{
    public static PlayerMovement Player;

    private InputAction moveAction;
    private InputAction jumpAction;

    [SerializeField]
    private CharacterController controller;

    [SerializeField]
    private CinemachineCamera cinemachineCamera;

    [SerializeField]
    private GameObject head;

    public GameObject Head => head;

    [Header("Movement variables")]
    [SerializeField]
    private float maxSpeed = 6.0f;
    [SerializeField]
    private float acceleration = 20.0f;
    [SerializeField]
    private float deceleration = 50.0f;

    private float speed = 0.0f;
    private Vector3 moveDirAlongFloor;
    private Transform cameraTransform;

    [Tooltip("Height at peak of jump")]
    [SerializeField]
    private float jumpHeight = 2.0f;

    [Tooltip("Time until peak")]
    [SerializeField]
    private float jumpTime = 0.2f;

    [Tooltip("Grace period after leaving ground where jumping is still possible")]
    [SerializeField]
    private float coyoteTime = 0.2f;

    public float verticalSpeed = 0.0f;

    private float jumpSpeed;
    private const float gravity = 22.0f;
    private float timeSinceLastOnFloor;
    public delegate void MoveEvent();
    public MoveEvent OnJump;

    private void Awake()
    {
        #region Singleton boilerplate

        if (Player != null)
        {
            if (Player != this)
            {
                Debug.LogWarning($"There's more than one {Player.GetType()} in the scene!", this);
                Destroy(gameObject);
            }

            return;
        }

        Player = this;

        #endregion Singleton boilerplate
    }

    void Start()
    {
        moveAction = InputSystem.actions.FindAction("Move");
        jumpAction = InputSystem.actions.FindAction("Jump");

        //From movement equations
        jumpSpeed = 2 * jumpHeight / jumpTime;
        
        timeSinceLastOnFloor = coyoteTime;

        Cursor.lockState = CursorLockMode.Locked;

        jumpAction.started += HandleJumping;

        cameraTransform = cinemachineCamera.transform;

    }

    private void Update()
    {
        HandleMovement();
        Debug.Log(speed);
    }

    void FixedUpdate()
    {
        timeSinceLastOnFloor = controller.isGrounded
            ? 0.0f : timeSinceLastOnFloor + Time.deltaTime;

        if (!controller.isGrounded)
        {
            // Apply gravity
            verticalSpeed -= gravity * Time.deltaTime;
        }
        else if (verticalSpeed < 0.0f)
        {
            // On floor, so reset gravity effect.
            verticalSpeed = 0.0f;
        }
    }

    private void HandleMovement()
    {
        var inputDir = moveAction.ReadValue<Vector2>().normalized;

        var moveDir = GetMoveDirAlongFloor(inputDir);
        var inputMagnitude = moveDir.magnitude;

        // Accelerate or decelerate
        var isMoving = inputMagnitude > 0.0f;

        if (isMoving)
        {
            moveDirAlongFloor = moveDir;

            // Limit the max speed using the input magnitude, so that if you're tilting
            // the joystick just a little bit, you won't move as fast at the maximum
            // (the speed up until this clamped max speed should be unaffected, though)
            var newSpeed = Math.Min(speed + Time.deltaTime * acceleration, inputMagnitude * maxSpeed);
            speed = newSpeed;
        }
        else
        {
            var newSpeed = Math.Max(speed - Time.deltaTime * deceleration, 0.0f);
            speed = newSpeed;
            Debug.Log("dec " + (speed - Time.deltaTime * deceleration));
          
        }

        var velocity = Vector3.up * verticalSpeed + moveDirAlongFloor * speed;
        controller.Move(Time.deltaTime * velocity);
        head.transform.rotation = cameraTransform.rotation;

    }

    private void HandleJumping(InputAction.CallbackContext _)
    {
        OnJump?.Invoke();
        if (timeSinceLastOnFloor < coyoteTime)
        {
            verticalSpeed = jumpSpeed;
            // Avoid chaining more jumps within grace period.
            timeSinceLastOnFloor = coyoteTime;
        }
    }

    private Vector3 GetMoveDirAlongFloor(Vector2 inputDir)
    {
        var forwardDir = new Vector3(cameraTransform.forward.x, 0.0f, cameraTransform.forward.z).normalized;
        var rightDir = new Vector3(cameraTransform.right.x, 0.0f, cameraTransform.right.z).normalized;

        return forwardDir * inputDir.y + rightDir * inputDir.x;
    }

    private void OnDestroy()
    {
        jumpAction.started -= HandleJumping;
    }
}
