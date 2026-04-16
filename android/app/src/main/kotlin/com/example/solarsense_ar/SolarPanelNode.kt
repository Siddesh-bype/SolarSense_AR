package com.example.solarsense_ar

import com.google.ar.sceneform.Node
import com.google.ar.sceneform.math.Vector3
import com.google.ar.sceneform.rendering.Color
import com.google.ar.sceneform.rendering.ModelRenderable

/**
 * A single physical solar panel placed on an AR plane.
 * Each node gets its own renderable copy for independent tinting.
 */
class SolarPanelNode(
    baseRenderable: ModelRenderable,
    localPos: Vector3,
) : Node() {

    private val normalColor     = Color(0.05f, 0.12f, 0.35f)
    private val obstructedColor = Color(0.55f, 0.05f, 0.05f)

    init {
        localPosition = localPos
        renderable = baseRenderable.makeCopy().apply {
            isShadowCaster   = true
            isShadowReceiver = true
        }
    }

    fun highlight(isObstructed: Boolean) {
        val r = renderable ?: return
        val color = if (isObstructed) obstructedColor else normalColor
        // Material instance is per-renderable-copy — set base colour directly
        r.material.setFloat3("baseColor",
            Vector3(color.r, color.g, color.b))
    }
}
