package com.example.solarsense_ar

import android.Manifest
import android.content.pm.PackageManager
import android.opengl.GLSurfaceView
import android.util.Log
import android.view.View
import android.widget.FrameLayout
import androidx.activity.ComponentActivity
import androidx.activity.result.ActivityResultLauncher
import androidx.core.content.ContextCompat
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import com.google.ar.core.Anchor
import com.google.ar.core.ArCoreApk
import com.google.ar.core.Config
import com.google.ar.core.Frame
import com.google.ar.core.Plane
import com.google.ar.core.Pose
import com.google.ar.core.Session
import com.google.ar.core.TrackingState
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.platform.PlatformView

/**
 * Pure ARCore + GLSurfaceView — no Filament, no SceneView dependency.
 * Completely avoids the Impeller/Filament Vulkan conflict.
 *
 * Init sequence:
 *  1. GLSurfaceView surface created → onSurfaceCreated fires on GL thread
 *  2. Renderer calls back → main thread checks/requests camera permission
 *  3. Permission granted → createSession() called
 *  4. Session configured and resumed, texture bound to OES texture
 *  5. onDrawFrame runs per-frame, ARCore planes detected, panels placed
 */
class ARSceneManager(
    private val activity: ComponentActivity,
    private val cameraPermLauncher: ActivityResultLauncher<String>,
) : PlatformView, DefaultLifecycleObserver {

    companion object {
        private const val TAG = "SolarSenseAR"
    }

    private val rootView      = FrameLayout(activity)
    private val glSurfaceView = GLSurfaceView(activity)
    private val renderer      = ARRenderer(activity, ::onFrame)

    private var session: Session? = null
    private var sessionCreated = false

    private var currentPlane: Plane? = null
    private val panelAnchors = mutableListOf<Anchor>()
    private var frameCount = 0

    var eventSink: EventChannel.EventSink? = null

    init {
        Log.e(TAG, "ARSceneManager.init")
        setupGLView()
        activity.lifecycle.addObserver(this)
        Log.e(TAG, "ARSceneManager.init -- complete")
    }

    private fun setupGLView() {
        glSurfaceView.preserveEGLContextOnPause = true
        glSurfaceView.setEGLContextClientVersion(2)
        glSurfaceView.setEGLConfigChooser(8, 8, 8, 8, 16, 0)
        glSurfaceView.setRenderer(renderer)
        glSurfaceView.renderMode = GLSurfaceView.RENDERMODE_CONTINUOUSLY

        // Fired on GL thread once surface is ready; we callback to UI thread
        renderer.onSurfaceReadyCallback = {
            Log.e(TAG, "GL surface ready")
            activity.runOnUiThread { checkPermissionAndSetup() }
        }

        rootView.addView(
            glSurfaceView,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT,
            )
        )
    }

    // ── Permission ────────────────────────────────────────────────────────────

    private fun checkPermissionAndSetup() {
        if (ContextCompat.checkSelfPermission(activity, Manifest.permission.CAMERA)
            == PackageManager.PERMISSION_GRANTED
        ) {
            Log.e(TAG, "Camera permission already granted")
            createSession()
        } else {
            Log.e(TAG, "Requesting camera permission")
            cameraPermLauncher.launch(Manifest.permission.CAMERA)
        }
    }

    /** Called from MainActivity when the user grants camera permission. */
    fun onCameraPermissionGranted() {
        Log.e(TAG, "onCameraPermissionGranted")
        createSession()
    }

    // ── Session ───────────────────────────────────────────────────────────────

    private fun createSession() {
        if (sessionCreated) return
        try {
            if (ArCoreApk.getInstance().requestInstall(activity, true)
                == ArCoreApk.InstallStatus.INSTALL_REQUESTED
            ) {
                Log.e(TAG, "ARCore install requested")
                return
            }

            val s = Session(activity)
            Config(s).apply {
                depthMode           = Config.DepthMode.AUTOMATIC
                lightEstimationMode = Config.LightEstimationMode.ENVIRONMENTAL_HDR
                planeFindingMode    = Config.PlaneFindingMode.HORIZONTAL
                updateMode          = Config.UpdateMode.LATEST_CAMERA_IMAGE
            }.also { s.configure(it) }

            Log.e(TAG, "ARCore session created — queuing GL-thread init")
            // CRITICAL: setCameraTextureName must be called on the GL thread AND
            // before session.resume(). Queue the whole startup sequence on GL thread.
            glSurfaceView.queueEvent {
                renderer.initCameraTexture(s)
                // Now resume on main thread (session.resume() is main-thread-safe)
                activity.runOnUiThread {
                    try {
                        s.resume()
                        glSurfaceView.onResume()
                        Log.e(TAG, "Session resumed after texture bind")
                    } catch (e: Exception) {
                        Log.e(TAG, "resume after texture FAILED: ${e.message}", e)
                    }
                }
            }

            session = s
            sessionCreated = true
            // Do NOT call resumeSession() here — done in queueEvent above
        } catch (e: Exception) {
            Log.e(TAG, "createSession FAILED: ${e.message}", e)
        }
    }

    private fun resumeSession() {
        try {
            session?.resume()
            glSurfaceView.onResume()
            Log.e(TAG, "Session resumed")
        } catch (e: Exception) {
            Log.e(TAG, "resumeSession FAILED: ${e.message}", e)
        }
    }

    // ── Lifecycle ─────────────────────────────────────────────────────────────

    override fun onResume(owner: LifecycleOwner) {
        if (sessionCreated) resumeSession()
    }

    override fun onPause(owner: LifecycleOwner) {
        if (sessionCreated) {
            glSurfaceView.onPause()
            session?.pause()
        }
    }

    // ── Per-frame (GL thread) ─────────────────────────────────────────────────

    private fun onFrame(frame: Frame) {
        frameCount++
        val s = session ?: return

        // getAllTrackables returns ALL known planes every frame.
        // getUpdatedTrackables only returns planes CHANGED this frame — returns 0 after initial detection.
        val allPlanes = s.getAllTrackables(Plane::class.java)

        if (frameCount % 60 == 0) {
            Log.e(TAG, "frame#$frameCount all_planes=${allPlanes.size} " +
                allPlanes.take(3).joinToString { "${it.type}|${it.trackingState}|${it.extentX}x${it.extentZ}" }
            )
        }

        val best = allPlanes
            .filter {
                it.type == Plane.Type.HORIZONTAL_UPWARD_FACING
                && it.trackingState == TrackingState.TRACKING
                && it.subsumedBy == null
            }
            .maxByOrNull { it.extentX * it.extentZ } ?: return

        val newArea  = best.extentX * best.extentZ
        val currArea = (currentPlane?.extentX ?: 0f) * (currentPlane?.extentZ ?: 0f)

        if (currentPlane == null || newArea > currArea * 1.1f) {
            Log.e(TAG, "Plane detected: ${best.extentX}x${best.extentZ}=${String.format("%.2f",newArea)}m2")
            activity.runOnUiThread { placeGrid(best) }
        }
        activity.runOnUiThread { streamHud() }
    }

    // ── Grid ──────────────────────────────────────────────────────────────────

    private fun placeGrid(plane: Plane, count: Int? = null) {
        clearAnchors()
        currentPlane = plane
        val positions = PanelGridCalculator.calculate(plane, count)
        Log.e(TAG, "placeGrid: ${positions.size} panels")
        for (pos in positions) {
            try {
                val anchor = plane.createAnchor(
                    plane.centerPose.compose(Pose.makeTranslation(pos.x, 0f, pos.z))
                )
                panelAnchors += anchor
                renderer.addAnchor(anchor)
            } catch (e: Exception) {
                Log.e(TAG, "createAnchor: ${e.message}")
            }
        }
    }

    private fun clearAnchors() {
        panelAnchors.forEach { it.detach() }
        panelAnchors.clear()
        renderer.clearAnchors()
    }

    // ── Public API ────────────────────────────────────────────────────────────

    fun addPanel()    { currentPlane?.let { placeGrid(it, (panelAnchors.size + 1).coerceAtMost(20)) } }
    fun removePanel() { if (panelAnchors.size > 1) { panelAnchors.last().detach(); panelAnchors.removeLastOrNull(); renderer.removeLastAnchor() } }
    fun resetScan()   { clearAnchors(); currentPlane = null }

    fun getScanSnapshot(): Map<String, Any> {
        val a = ((currentPlane?.extentX ?: 0f) * (currentPlane?.extentZ ?: 0f)).toDouble()
        return mapOf("panelCount" to panelAnchors.size, "systemKw" to panelAnchors.size * 0.54, "areaSqm" to a, "planeFound" to (currentPlane != null))
    }

    private fun streamHud() {
        val sink = eventSink ?: return
        val a = ((currentPlane?.extentX ?: 0f) * (currentPlane?.extentZ ?: 0f)).toDouble()
        try {
            sink.success(mapOf(
                "panelCount" to panelAnchors.size, "maxPanels" to PanelGridCalculator.maxPanelsFor(a.toFloat()),
                "systemKw" to panelAnchors.size * 0.54, "areaSqm" to a, "planeFound" to (currentPlane != null),
            ))
        } catch (_: Exception) {}
    }

    // ── PlatformView ──────────────────────────────────────────────────────────

    override fun getView(): View = rootView

    override fun dispose() {
        activity.lifecycle.removeObserver(this)
        clearAnchors()
        try { glSurfaceView.onPause() } catch (_: Exception) {}
        session?.close(); session = null
    }
}
