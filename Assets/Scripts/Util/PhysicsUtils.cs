using System;
using UnityEngine;

public class Layer
{
    private const int numBits = 32;
    private static readonly int[] collisionMasks = new int[numBits];

    public static readonly Layer DEFAULT = new("Default");
    /// <summary>The player itself and its constituent objects.</summary>
    public static readonly Layer PLAYER = new("Player");
    /// <summary>All masks.</summary>
    public static readonly Layer MASKS = new("Masks");

    /// <example>
    /// Making a rigidbody additionally collide with layer <c>A</c> and <c>B</c>:
    /// <code>
    /// rigidbody.includeLayers |= Layer.A.mask | Layer.B.mask;
    /// </code>
    /// </example>
    public readonly int mask;

    /// <example>
    /// Ensuring that a rigidbody's <c>includeLayers</c> doesn't include layer
    /// <c>A</c>:
    /// <code>
    /// rigidbody.includeLayers &amp;= Layer.A.invertedMask;
    /// </code>
    /// </example>
    public readonly int invertedMask;

    /// <summary>
    /// A mask of all other layers that this layer collides with - or more
    /// specifically, the layers that it <i>doesn't ignore</i> colliding with.
    /// </summary>
    public int CollisionMaskWithOtherLayers => collisionMasks[value];

    private readonly int value;

    private Layer(string layerName)
    {
        value = LayerMask.NameToLayer(layerName);
        mask = 1 << value;
        invertedMask = ~mask;

        AddCollisionMask();
    }

    public override string ToString()
    {
        return $"Layer #{value} (mask: 0b{Convert.ToString(mask, 2)})";
    }

    public static implicit operator int(Layer layer)
    {
        return layer.value;
    }

    private void AddCollisionMask()
    {
        var collisionMask = 0;
        for (var layerValue = 0; layerValue < numBits; layerValue++)
        {
            if(!Physics.GetIgnoreLayerCollision(layerValue, value))
                collisionMask |= 1 << layerValue;
        }
        collisionMasks[value] = collisionMask;
    }
}
