package com.example.solarsense_ar

import android.content.Context
import android.view.View
import com.google.ar.core.ArCoreApk
import com.google.ar.core.Config
import com.google.ar.core.Plane
import com.google.ar.core.Session
import com.google.ar.core.TrackingState
import com.google.ar.sceneform.ArSceneView
import com.google.ar.sceneform.rendering.ModelRenderable
import io.flutter.plugin.platform.PlatformView

/**
 * Wraps [ArSceneView] as a Flutter [PlatformView].
 * Configures ARCore session with depth + HDR lighting.
 * Detects the largest horizontal plane, then calls [PanelGridManager.buildGrid].
 */
class ARSceneManager(private val context: Context) : PlatformView {

    val arSceneView: ArSceneView = ArSceneView(context)
    private val gridManager = PanelGridManager(arSceneView.scene)

    private var session: Session? = null
    private var panelRenderable: ModelRenderable? = null
    private var gridBuilt = false
    private var currentNodes = emptyList<SolarPanelNode>()

    var requestedPanelCount: Int = 12

    init {
        setupAR()
        loadMaterial()
        registerFrameListener()
    }

    override fun getView(): View = arSceneView

    override fun dispose() {
        arSceneView.destroy()
        session?.close()
        PanelMaterialFactory.invalidate()
    }

    // ── AR Setup ──────────────────────────────────────────────────────────────

    private fun setupAR() {
        try {
            val availability = ArCoreApk.getInstance().checkAvailability(context)
            if (!availability.isSupported) return

            val s = Session(context)
            val config = Config(s).apply {
                planeFindingMode    = Config.PlaneFindingMode.HORIZONTAL_AND_VERTICAL
                lightEstimationMode = Config.LightEstimationMode.ENVIRONMENTAL_HDR
                depthMode           = if (s.isDepthModeSupported(Config.DepthMode.AUTOMATIC))
                                          Config.DepthMode.AUTOMATIC
                                      else Config.DepthMode.DISABLED
                updateMode          = Config.UpdateMode.LATEST_CAMERA_IMAGE
            }
            s.configure(config)
            arSceneView.session = s
            session = s
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun loadMaterial() {
        PanelMaterialFactory.build(context)
            .thenAccept { r -> panelRenderable = r }
            .exceptionally { null }
    }

    private fun registerFrameListener() {
        arSceneView.scene.addOnUpdateListener {
            val frame      = arSceneView.arFrame ?: return@addOnUpdateListener
            val camera     = frame.camera
            if (camera.trackingState != TrackingState.TRACKING) return@addOnUpdateListener

            val renderable = panelRenderable ?: return@addOnUpdateListener
            if (gridBuilt) return@addOnUpdateListener

            // getUpdatedTrackables is the correct ARCore API for Sceneform 1.23
            val largestPlane = frame
                .getUpdatedTrackables(Plane::class.java)
                .filter { it.type == Plane.Type.HORIZONTAL_UPWARD_FACING &&
                          it.trackingState == TrackingState.TRACKING &&
                          it.subsumedBy == null }
                .maxByOrNull { it.extentX * it.extentZ }
                ?: return@addOnUpdateListener

            // Require at least a 1m × 0.75m surface before building grid
            if (largestPlane.extentX < 1f || largestPlane.extentZ < 0.75f) return@addOnUpdateListener

            val anchor = largestPlane.createAnchor(largestPlane.centerPose)
            val result = gridManager.buildGrid(
                plane          = largestPlane,
                anchor         = anchor,
                renderable     = renderable,
                requestedCount = requestedPanelCount,
            ) ?: return@addOnUpdateListener

            currentNodes = result.nodes
            gridBuilt    = true
        }
    }

    // ── Public API ────────────────────────────────────────────────────────────

    fun resetGrid() {
        currentNodes.forEach { it.setParent(null) }
        currentNodes = emptyList()
        gridBuilt    = false
    }

    fun updateObstacleCount(count: Int) {
        gridManager.updateObstacles(currentNodes, count)
    }

    fun resume() { try { arSceneView.resume() } catch (_: Exception) {} }
    fun pause()  { arSceneView.pause() }
}
