using TMPro;
using UnityEngine;
using static PlayerMovement;

public class MaskHolder : MonoBehaviour
{
    [SerializeField]
    private TMP_Text hudText;

    private Mask equippedMask;

    void Start()
    {
        hudText.text = "";
    }

    void FixedUpdate()
    {
        CheckLookingAtMask();
    }

    private void CheckLookingAtMask(bool debug = true)
    {
        var playerHead = Player.Head.transform;

        if (debug)
        {
            Debug.DrawRay(
                playerHead.position,
                playerHead.TransformDirection(Vector3.forward) * 1000,
                Color.red
            );
        }

        if (Physics.Raycast(
                playerHead.position,
                playerHead.TransformDirection(Vector3.forward),
                out var hit,
                Mathf.Infinity,
                Layer.MASKS.mask
            ))
        {
            hudText.text = hit.collider.name;
        }
        else
            hudText.text = "";
    }
}
