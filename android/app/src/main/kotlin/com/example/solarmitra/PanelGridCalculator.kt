package com.example.solarmitra

import com.google.ar.core.Plane
import kotlin.math.abs
import kotlin.math.roundToInt

/** Simple (x, z) offset from the plane centre — Y is always 0 (handled by anchor pose). */
data class GridPosition(val x: Float, val z: Float)

/** Layout style for placing modules in a grid over the detected plane. */
enum class PanelLayout { AUTO, LANDSCAPE, PORTRAIT }

object PanelGridCalculator {

    // Default PV module (540 Wp mono-PERC) + inter-module gap.
    const val PANEL_W = 1.70f
    const val PANEL_D = 1.14f
    const val PANEL_AREA = PANEL_W * PANEL_D   // 1.938 m²
    private const val GAP  = 0.06f
    private const val MAX_PANELS = 24

    data class FlexSpec(val widthM: Float, val heightM: Float, val layout: PanelLayout)

    /** Adaptive grid placement over the plane. [spec] controls module size and
     *  orientation so different panel sizes/layouts can be offered on-device. */
    fun calculate(plane: Plane, count: Int? = null, spec: FlexSpec = FlexSpec(PANEL_W, PANEL_D, PanelLayout.AUTO)): List<GridPosition> {
        val extX = plane.extentX.coerceAtLeast(0.5f)
        val extZ = plane.extentZ.coerceAtLeast(0.5f)

        val (cellW, cellD) = when (spec.layout) {
            PanelLayout.PORTRAIT -> { // long edge along Z (depth)
                Pair(spec.heightM + GAP, spec.widthM + GAP)
            }
            PanelLayout.LANDSCAPE -> { // long edge along X (width)
                Pair(spec.widthM + GAP, spec.heightM + GAP)
            }
            PanelLayout.AUTO -> {
                // Choose whichever orientation fits the roof rectangle best.
                if (extX >= extZ) Pair(spec.widthM + GAP, spec.heightM + GAP)
                else Pair(spec.heightM + GAP, spec.widthM + GAP)
            }
        }

        // Floor to whole rows/cols so we never overhang the detected region.
        val cols = (extX / cellW).toInt().coerceAtLeast(1)
        val rows = (extZ / cellD).toInt().coerceAtLeast(1)
        val maxFit = (cols * rows).coerceAtMost(MAX_PANELS)
        val target = count?.coerceIn(1, maxFit) ?: maxFit

        val startX = -(cols / 2f - 0.5f) * cellW
        val startZ = -(rows / 2f - 0.5f) * cellD

        // Fills modules from the plane centre outward (most reliable anchor at
        // the centre of the detected region first) in a spiral-ish order.
        val positions = mutableListOf<GridPosition>()
        val used = mutableListOf<GridPosition>()
        var radius = 0
        while (positions.size < target) {
            val available = mutableListOf<GridPosition>()
            for (row in 0 until rows) {
                for (col in 0 until cols) {
                    val p = GridPosition(startX + col * cellW, startZ + row * cellD)
                    if (used.contains(p)) continue
                    val dRow = row - (rows - 1) / 2f
                    val dCol = col - (cols - 1) / 2f
                    val ring = maxOf(kotlin.math.abs(dRow), kotlin.math.abs(dCol))
                    if (ring.roundToInt() == radius) available += p
                }
            }
            available.sortBy { it.x * it.x + it.z * it.z }
            positions += available
            used += available
            radius++
        }
        return positions.take(target)
    }

    fun maxPanelsFor(areaSqm: Float, spec: FlexSpec = FlexSpec(PANEL_W, PANEL_D, PanelLayout.AUTO)): Int {
        val cell = spec.widthM * spec.heightM
        return (areaSqm / cell).toInt().coerceAtMost(MAX_PANELS)
    }
}