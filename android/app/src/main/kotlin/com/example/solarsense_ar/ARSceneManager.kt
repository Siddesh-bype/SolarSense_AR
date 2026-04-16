package com.example.solarsense_ar

import android.util.Log
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
 * Real ARCore session via SceneView 2.2.1 as a Flutter Hybrid Composition PlatformView.
 *
 * Important lifecycle note:
 *   ARSceneView creates the ARCore Session after the view is attached to
 *   the window. We set onSessionUpdated inside the onSessionCreated callback
 *   to ensure the session already exists when we hook its frame listener.
 *
 * Model loading:
 *   loadModelInstanceAsync returns FilamentInstance? (nullable).
 *   ModelNode(instance, scaleToUnits = 1.7f) wraps it into a visible node.
 */
class ARSceneManager(
    private val activity: ComponentActivity,
) : PlatformView {

    companion object {
        private const val TAG = "SolarSenseAR"
    }

    private val arSceneView = ARSceneView(
        context         = activity,
        sharedActivity  = activity,
        sharedLifecycle = activity.lifecycle,
    )

    private val modelLoader = ModelLoader(arSceneView.engine, activity)
    private val anchorNodes = mutableListOf<AnchorNode>()
    private var currentPlane: Plane? = null

    var eventSink: EventChannel.EventSink? = null

    init {
        Log.d(TAG, "▶ ARSceneManager.init — view created, awaiting session")

        // sessionConfiguration fires BEFORE session.resume() to apply the config
        arSceneView.sessionConfiguration = { _: Session, config: Config ->
            Log.d(TAG, "✔ sessionConfiguration applied")
            config.depthMode           = Config.DepthMode.AUTOMATIC
            config.lightEstimationMode = Config.LightEstimationMode.ENVIRONMENTAL_HDR
            config.planeFindingMode    = Config.PlaneFindingMode.HORIZONTAL
        }

        // onSessionCreated fires once the session is fully initialized —
        // this is the right place to wire the per-frame callback
        arSceneView.onSessionCreated = { _: Session ->
            Log.d(TAG, "✔ ARCore session created — wiring frame listener")
            arSceneView.onSessionUpdated = { _: Session, frame: Frame ->
                onFrame(frame)
            }
        }

        arSceneView.onSessionFailed = { e: Exception ->
            Log.e(TAG, "✖ ARCore session FAILED: ${e.message}", e)
        }
    }

    // ── Per-frame plane tracking ───────────────────────────────────────────────

    private fun onFrame(frame: Frame) {
        val tracked = frame
            .getUpdatedTrackables(Plane::class.java)
            .filter { p: Plane ->
                p.type == Plane.Type.HORIZONTAL_UPWARD_FACING
                && p.trackingState == TrackingState.TRACKING
                && p.subsumedBy == null
            }
            .maxByOrNull { p: Plane -> p.extentX * p.extentZ }
            ?: return

        val newArea  = tracked.extentX * tracked.extentZ
        val currArea = (currentPlane?.extentX ?: 0f) * (currentPlane?.extentZ ?: 0f)

        Log.d(TAG, "Plane: ${tracked.extentX}m × ${tracked.extentZ}m = ${"%.2f".format(newArea)}m²")

        if (currentPlane == null || newArea > currArea * 1.1f) {
            rebuildGrid(tracked)
        }
        streamHud()
    }

    // ── Grid ─────────────────────────────────────────────────────────────────

    private fun rebuildGrid(plane: Plane, requestedCount: Int? = null) {
        clearNodes()
        currentPlane = plane

        val positions = PanelGridCalculator.calculate(plane, requestedCount)
        Log.d(TAG, "rebuildGrid → ${positions.size} panels")

        for (pos in positions) {
            try {
                val pose   = plane.centerPose.compose(
                    com.google.ar.core.Pose.makeTranslation(pos.x, 0f, pos.z)
                )
                val anchor = plane.createAnchor(pose)

                val anchorNode = AnchorNode(arSceneView.engine, anchor)
                arSceneView.addChildNode(anchorNode)
                anchorNodes += anchorNode

                modelLoader.loadModelInstanceAsync(
                    fileLocation = "models/solar_panel.glb",
                ) { instance: FilamentInstance? ->
                    if (instance != null) {
                        Log.d(TAG, "✔ GLB loaded — attaching ModelNode")
                        anchorNode.addChildNode(
                            ModelNode(modelInstance = instance, scaleToUnits = 1.7f)
                        )
                    } else {
                        Log.e(TAG, "✖ GLB returned null — check asset path 'models/solar_panel.glb'")
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Panel placement error: ${e.message}", e)
            }
        }
    }

    private fun clearNodes() {
        anchorNodes.forEach {
            try { it.destroy() } catch (e: Exception) { Log.w(TAG, e.message ?: "destroy error") }
        }
        anchorNodes.clear()
    }

    // ── Public API (MethodChannel) ────────────────────────────────────────────

    fun addPanel()    { currentPlane?.let { rebuildGrid(it, (anchorNodes.size + 1).coerceAtMost(20)) } }
    fun removePanel() { if (anchorNodes.size > 1) currentPlane?.let { rebuildGrid(it, anchorNodes.size - 1) } }
    fun resetScan()   { clearNodes(); currentPlane = null }

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
        } catch (e: Exception) { Log.w(TAG, "EventSink.success() failed: ${e.message}") }
    }

    // ── PlatformView ──────────────────────────────────────────────────────────

    override fun getView(): View = arSceneView
    override fun dispose() {
        Log.d(TAG, "dispose()")
        clearNodes()
        try { arSceneView.destroy() } catch (e: Exception) { Log.w(TAG, "destroy: ${e.message}") }
    }
}
