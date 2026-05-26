package com.example.solarmitra

import com.google.ar.core.Plane

/** Simple (x, z) offset from the plane centre — Y is always 0 (handled by anchor pose). */
data class GridPosition(val x: Float, val z: Float)

object PanelGridCalculator {

    private const val CELL_W     = 1.75f   // panel width  + gap
    private const val CELL_D     = 1.20f   // panel depth  + gap
    const val PANEL_W            = 1.70f
    const val PANEL_D            = 1.14f
    const val PANEL_AREA         = PANEL_W * PANEL_D   // 1.938 m²
    private const val MAX_PANELS = 20

    fun calculate(plane: Plane, requestedCount: Int? = null): List<GridPosition> {
        val cols   = (plane.extentX / CELL_W).toInt().coerceAtLeast(1)
        val rows   = (plane.extentZ / CELL_D).toInt().coerceAtLeast(1)
        val maxFit = (cols * rows).coerceAtMost(MAX_PANELS)
        val target = requestedCount?.coerceIn(1, maxFit) ?: maxFit

        val startX = -(cols / 2f - 0.5f) * CELL_W
        val startZ = -(rows / 2f - 0.5f) * CELL_D

        val positions = mutableListOf<GridPosition>()
        outer@ for (row in 0 until rows) {
            for (col in 0 until cols) {
                if (positions.size >= target) break@outer
                positions += GridPosition(
                    x = startX + col * CELL_W,
                    z = startZ + row * CELL_D,
                )
            }
        }
        return positions
    }

    fun maxPanelsFor(areaSqm: Float): Int =
        (areaSqm / PANEL_AREA).toInt().coerceAtMost(MAX_PANELS)
}
