package com.example.solarmitra

import com.google.ar.core.Anchor
import kotlin.math.abs

/**
 * One independently-placed PV module in the AR scene.
 *
 * The anchor sits on the ROOF PLANE (elevation 0) and carries only the yaw
 * (azimuth) rotation. Elevation and tilt are applied by the renderer in the
 * model matrix, which means height and tilt can be changed every frame without
 * detaching/recreating the ARCore anchor — only a move needs a new anchor.
 */
data class Panel(
    val id: Int,
    var anchor: Anchor,
    var widthM: Float,
    var heightM: Float,
    var elevationM: Float,
    var tiltDeg: Float,
    var azimuthDeg: Float,
    /** Plane-local XZ offset from the plane centre, kept so a panel can be
     *  re-anchored (move, plane re-detect) without losing its ground position. */
    var localX: Float,
    var localZ: Float,
    var selected: Boolean = false,
    /** Dim factor 0..1 — panels sitting inside an obstacle keep-out render faded. */
    var occlusion: Float = 1.0f,
    /** Set once the user moves/resizes/raises this panel. Plane re-detection
     *  stops re-seeding the layout after that, so manual work isn't wiped. */
    var moved: Boolean = false,
) {
    val areaM2: Float get() = widthM * heightM

    /** Peak power for this module: ≈470 Wp for the reference 1.70 × 1.14 m
     *  panel, scaled by area so mixed-size arrays report a real system size. */
    val kw: Double
        get() = 0.470 * areaM2 /
            (PanelGridCalculator.PANEL_W * PanelGridCalculator.PANEL_D)
}

/**
 * A rooftop obstacle keep-out zone in plane-local XZ metres (from plane centre).
 * Produced by ray-casting a YOLO detection onto the tracked plane; sized from
 * the obstacle's real-world footprint plus an installation setback.
 */
data class KeepOut(
    val x: Float,
    val z: Float,
    val halfW: Float,
    val halfD: Float,
    val label: String,
) {
    /** True when an axis-aligned panel footprint overlaps this zone. */
    fun overlaps(px: Float, pz: Float, panelHalfW: Float, panelHalfD: Float): Boolean =
        abs(px - x) < (panelHalfW + halfW) && abs(pz - z) < (panelHalfD + halfD)

    fun contains(px: Float, pz: Float): Boolean =
        abs(px - x) <= halfW && abs(pz - z) <= halfD
}
