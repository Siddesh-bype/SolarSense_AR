package com.example.solarsense_ar

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.view.View
import androidx.core.content.ContextCompat
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
 *
 * Key fix: call arSceneView.resume() inside init{} — because Flutter creates
 * the platform view AFTER Activity.onResume() has already fired, so the
 * onResume() lifecycle hook in MainActivity is too early to start the camera.
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
        // ← Critical: resume here so the camera feed starts immediately.
        //   MainActivity.onResume() fires before the AndroidView is inflated,
        //   so arSceneView.resume() was previously a no-op.
        resume()
    }

    override fun getView(): View = arSceneView

    override fun dispose() {
        try { arSceneView.destroy() } catch (_: Exception) {}
        session?.close()
        PanelMaterialFactory.invalidate()
    }

    // ── AR Setup ──────────────────────────────────────────────────────────────

    private fun setupAR() {
        // Guard: camera permission must be granted before creating a Session
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA)
                != PackageManager.PERMISSION_GRANTED) {
            return // Flutter's camera permission dialog will handle this
        }
        try {
            // Check ARCore is installed and supported on this device
            val install = ArCoreApk.getInstance().requestInstall(
                context as android.app.Activity, true
            )
            if (install == ArCoreApk.InstallStatus.INSTALL_REQUESTED) return

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
            // Sceneform 1.23 — set session via property
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
            val frame  = arSceneView.arFrame ?: return@addOnUpdateListener
            if (frame.camera.trackingState != TrackingState.TRACKING) return@addOnUpdateListener

            val renderable = panelRenderable ?: return@addOnUpdateListener
            if (gridBuilt) return@addOnUpdateListener

            val largestPlane = frame
                .getUpdatedTrackables(Plane::class.java)
                .filter {
                    it.type  == Plane.Type.HORIZONTAL_UPWARD_FACING &&
                    it.trackingState == TrackingState.TRACKING &&
                    it.subsumedBy == null
                }
                .maxByOrNull { it.extentX * it.extentZ }
                ?: return@addOnUpdateListener

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

    fun resume() {
        try { arSceneView.resume() } catch (_: Exception) {}
    }

    fun pause() {
        try { arSceneView.pause() } catch (_: Exception) {}
    }
}
