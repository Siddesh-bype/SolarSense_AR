package com.example.solarsense_ar

import com.google.ar.core.Plane
import io.github.sceneview.math.Position

/**
 * Calculates a grid of world-space positions for solar panels on a detected [Plane].
 *
 * Panel footprint (with 5cm gap):
 *   cellW = 1.70 + 0.05 = 1.75 m
 *   cellD = 1.14 + 0.06 = 1.20 m
 *
 * Uses the plane's extentX / extentZ (full width/depth) to find how many columns
 * and rows fit. Returns up to [maxCount] positions, centred on the plane's centre.
 */
object PanelGridCalculator {

    private const val CELL_W   = 1.75f   // panel width + gap
    private const val CELL_D   = 1.20f   // panel depth + gap
    const val PANEL_W          = 1.70f   // actual panel width (for kW calc)
    const val PANEL_D          = 1.14f   // actual panel depth
    const val PANEL_AREA       = PANEL_W * PANEL_D   // 1.938 m²
    private const val MAX_PANELS = 20

    /**
     * Returns world-space [Position] list for panels that fit inside [plane].
     * [requestedCount] lets Flutter override the auto-calculated count.
     */
    fun calculate(plane: Plane, requestedCount: Int? = null): List<Position> {
        val cols = (plane.extentX / CELL_W).toInt().coerceAtLeast(1)
        val rows = (plane.extentZ / CELL_D).toInt().coerceAtLeast(1)
        val maxFit = (cols * rows).coerceAtMost(MAX_PANELS)
        val target = requestedCount?.coerceIn(1, maxFit) ?: maxFit

        // Centre the grid on the plane
        val startX = -(cols / 2f - 0.5f) * CELL_W
        val startZ = -(rows / 2f - 0.5f) * CELL_D

        // Plane Y (height) from the plane's centre pose
        val planeY = plane.centerPose.ty()

        val positions = mutableListOf<Position>()
        outer@ for (row in 0 until rows) {
            for (col in 0 until cols) {
                if (positions.size >= target) break@outer
                positions += Position(
                    x = startX + col * CELL_W,
                    y = planeY + 0.01f,   // 1cm above surface so panels don't z-fight
                    z = startZ + row * CELL_D,
                )
            }
        }
        return positions
    }

    /** How many panels fit given a plane area (for HUD display when plane just found). */
    fun maxPanelsFor(areaSqm: Float): Int =
        (areaSqm / PANEL_AREA).toInt().coerceAtMost(MAX_PANELS)
}
