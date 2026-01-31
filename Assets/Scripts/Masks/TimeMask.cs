using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

public class TimeMask : MonoBehaviour, Mask
{
    [SerializeField]
    private LayerMask affectedObjectLayer;
    private Dictionary<Rigidbody, (Vector3 linearVelocity, Vector3 angularVelocity)> FrozenObjects = new Dictionary<Rigidbody, (Vector3 linearVelocity, Vector3 angularVelocity)>();

    public void OnEquipped()
    {
        foreach (var item in FindObjectsByType<GameObject>(sortMode: FindObjectsSortMode.None))
            if ((affectedObjectLayer.value & (1 << item.layer)) != 0 && item.TryGetComponent<Rigidbody>(out var body))
            {
                FrozenObjects.Add(body, (body.linearVelocity, body.angularVelocity));
                body.isKinematic = true;
            }
    }

    public void OnUnequipped()
    {
        foreach (var item in FrozenObjects)
        {
            if (item.Key == null) return;
            item.Key.isKinematic = false;
            item.Key.angularVelocity = item.Value.angularVelocity;
            item.Key.linearVelocity = item.Value.linearVelocity;
        }
        FrozenObjects.Clear();
    }
}
