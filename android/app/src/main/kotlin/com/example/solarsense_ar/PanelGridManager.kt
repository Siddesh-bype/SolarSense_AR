package com.example.solarsense_ar

import com.google.ar.core.Anchor
import com.google.ar.core.Plane
import com.google.ar.sceneform.AnchorNode
import com.google.ar.sceneform.Scene
import com.google.ar.sceneform.math.Vector3
import com.google.ar.sceneform.rendering.ModelRenderable

/**
 * Fits solar panels on a detected [Plane] using extentX / extentZ (correct ARCore API).
 * Cell footprint with gap:  (WIDTH+0.05)m wide × (DEPTH+0.06)m deep.
 */
class PanelGridManager(private val scene: Scene) {

    data class GridResult(
        val nodes: List<SolarPanelNode>,
        val panelCount: Int,
        val systemKw: Double,
    )

    private val cellW = PanelMaterialFactory.WIDTH  + 0.05f   // 1.75m
    private val cellD = PanelMaterialFactory.DEPTH  + 0.06f   // 1.20m

    fun buildGrid(
        plane: Plane,
        anchor: Anchor,
        renderable: ModelRenderable,
        requestedCount: Int = 12,
    ): GridResult? {
        // extentX / extentZ are full dimensions (not half) of the plane bounding box
        val cols = (plane.extentX / cellW).toInt().coerceAtLeast(1)
        val rows = (plane.extentZ / cellD).toInt().coerceAtLeast(1)
        val maxFit = cols * rows
        if (maxFit == 0) return null

        val count      = requestedCount.coerceAtMost(maxFit)
        val anchorNode = AnchorNode(anchor).also { it.setParent(scene) }
        val nodes      = mutableListOf<SolarPanelNode>()

        val startX = -(cols / 2f - 0.5f) * cellW
        val startZ = -(rows / 2f - 0.5f) * cellD
        var placed = 0

        outer@ for (row in 0 until rows) {
            for (col in 0 until cols) {
                if (placed >= count) break@outer
                val node = SolarPanelNode(
                    baseRenderable = renderable,
                    localPos = Vector3(startX + col * cellW, 0f, startZ + row * cellD),
                )
                node.setParent(anchorNode)
                nodes.add(node)
                placed++
            }
        }

        return GridResult(nodes = nodes, panelCount = placed, systemKw = placed * 0.25)
    }

    fun updateObstacles(nodes: List<SolarPanelNode>, obstacleCount: Int) {
        nodes.forEachIndexed { idx, node -> node.highlight(idx < obstacleCount) }
    }
}
