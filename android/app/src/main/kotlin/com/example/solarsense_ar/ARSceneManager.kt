package com.example.solarsense_ar

import android.content.Context
import android.view.View
import androidx.activity.ComponentActivity
import com.google.ar.core.Config
import com.google.ar.core.Frame
import com.google.ar.core.Plane
import com.google.ar.core.Session
import com.google.ar.core.TrackingState
import com.google.android.filament.gltfio.FilamentInstance
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.platform.PlatformView
import io.github.sceneview.ar.ARSceneView
import io.github.sceneview.ar.node.AnchorNode
import io.github.sceneview.loaders.ModelLoader
import io.github.sceneview.node.ModelNode

/**
 * Manages a real ARCore + SceneView 2.2.1 scene as a Flutter PlatformView.
 *
 * API verified from bytecode (arsceneview-2.2.1.aar + sceneview-2.2.1.aar):
 *   - ARSceneView(context, activity, lifecycle) — named params, rest defaulted
 *   - sessionConfiguration = { session, config -> … }  (property setter)
 *   - onSessionUpdated = { session, frame -> … }        (property setter)
 *   - ModelLoader.loadModelInstanceAsync(fileLocation, onResult)
 *   - AnchorNode(engine, anchor)
 *   - ModelNode(modelInstance, scaleToUnits = 1.7f)
 *   - Node.addChildNode(child)
 */
class ARSceneManager(
    private val activity: ComponentActivity,
) : PlatformView {

    private val arSceneView = ARSceneView(
        context        = activity,
        sharedActivity = activity,
        sharedLifecycle = activity.lifecycle,
    )

    private val modelLoader = ModelLoader(arSceneView.engine, activity)

    private val anchorNodes   = mutableListOf<AnchorNode>()
    private var currentPlane: Plane? = null

    var eventSink: EventChannel.EventSink? = null

    init {
        // sessionConfiguration is a property in 2.2.1 (not configureSession method)
        arSceneView.sessionConfiguration = { _: Session, config: Config ->
            config.depthMode           = Config.DepthMode.AUTOMATIC
            config.lightEstimationMode = Config.LightEstimationMode.ENVIRONMENTAL_HDR
            config.planeFindingMode    = Config.PlaneFindingMode.HORIZONTAL
        }

        arSceneView.onSessionUpdated = { _: Session, frame: Frame ->
            val tracked = frame
                .getUpdatedTrackables(Plane::class.java)
                .filter { p: Plane ->
                    p.type == Plane.Type.HORIZONTAL_UPWARD_FACING
                    && p.trackingState == TrackingState.TRACKING
                    && p.subsumedBy == null
                }
                .maxByOrNull { p: Plane -> p.extentX * p.extentZ }

            if (tracked != null) {
                val newArea  = tracked.extentX * tracked.extentZ
                val currArea = (currentPlane?.extentX ?: 0f) * (currentPlane?.extentZ ?: 0f)
                if (currentPlane == null || newArea > currArea * 1.2f) {
                    rebuildGrid(tracked)
                }
                streamHud()
            }
        }
    }

    override fun getView(): View = arSceneView
    override fun dispose()       { clearNodes(); try { arSceneView.destroy() } catch (_: Exception) {} }

    // ── Grid ─────────────────────────────────────────────────────────────────

    private fun rebuildGrid(plane: Plane, requestedCount: Int? = null) {
        clearNodes()
        currentPlane = plane

        for (pos in PanelGridCalculator.calculate(plane, requestedCount)) {
            try {
                val anchor = plane.createAnchor(
                    plane.centerPose.compose(
                        com.google.ar.core.Pose.makeTranslation(pos.x, 0f, pos.z)
                    )
                )

                val anchorNode = AnchorNode(arSceneView.engine, anchor)
                arSceneView.addChildNode(anchorNode)
                anchorNodes += anchorNode

                modelLoader.loadModelInstanceAsync(
                    fileLocation = "models/solar_panel.glb",
                ) { instance: FilamentInstance? ->
                    if (instance != null) {
                        anchorNode.addChildNode(
                            ModelNode(modelInstance = instance, scaleToUnits = 1.7f)
                        )
                    }
                }
            } catch (e: Exception) { e.printStackTrace() }
        }
    }

    private fun clearNodes() {
        anchorNodes.forEach { try { it.destroy() } catch (_: Exception) {} }
        anchorNodes.clear()
    }

    // ── Public API ────────────────────────────────────────────────────────────

    fun addPanel() {
        currentPlane?.let { rebuildGrid(it, (anchorNodes.size + 1).coerceAtMost(20)) }
    }

    fun removePanel() {
        if (anchorNodes.size > 1) currentPlane?.let { rebuildGrid(it, anchorNodes.size - 1) }
    }

    fun resetScan() { clearNodes(); currentPlane = null }

    fun getScanSnapshot(): Map<String, Any> {
        val area = ((currentPlane?.extentX ?: 0f) * (currentPlane?.extentZ ?: 0f)).toDouble()
        return mapOf(
            "panelCount" to anchorNodes.size,
            "systemKw"   to anchorNodes.size * 0.54,
            "areaSqm"    to area,
            "planeFound" to (currentPlane != null),
        )
    }

    // ── HUD stream ────────────────────────────────────────────────────────────

    private fun streamHud() {
        val sink = eventSink ?: return
        val area = ((currentPlane?.extentX ?: 0f) * (currentPlane?.extentZ ?: 0f)).toDouble()
        try {
            sink.success(mapOf(
                "panelCount" to anchorNodes.size,
                "maxPanels"  to PanelGridCalculator.maxPanelsFor(area.toFloat()),
                "systemKw"   to anchorNodes.size * 0.54,
                "areaSqm"    to area,
                "planeFound" to (currentPlane != null),
            ))
        } catch (_: Exception) {}
    }
}
