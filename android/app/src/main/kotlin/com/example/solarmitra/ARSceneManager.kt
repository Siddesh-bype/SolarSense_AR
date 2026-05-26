package com.example.solarmitra

import android.Manifest
import android.content.ComponentCallbacks2
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.opengl.GLSurfaceView
import android.util.Log
import android.view.Surface
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
        private const val TAG = "SolarMitra"
    }

    private val rootView      = FrameLayout(activity)
    private val glSurfaceView = GLSurfaceView(activity)
    private val renderer      = ARRenderer(activity, ::onFrame, ::currentDisplayRotation)

    private fun currentDisplayRotation(): Int = try {
        @Suppress("DEPRECATION")
        activity.windowManager?.defaultDisplay?.rotation ?: Surface.ROTATION_0
    } catch (_: Exception) { Surface.ROTATION_0 }

    private val orientationCallback = object : ComponentCallbacks2 {
        override fun onConfigurationChanged(newConfig: Configuration) {
            Log.e(TAG, "Configuration changed: orientation=${newConfig.orientation}")
            glSurfaceView.queueEvent { renderer.onDisplayRotationChanged() }
        }
        override fun onLowMemory() {}
        override fun onTrimMemory(level: Int) {}
    }

    private var session: Session? = null
    private var sessionCreated = false

    private var currentPlane: Plane? = null
    private val panelAnchors = mutableListOf<Anchor>()
    private var frameCount = 0

    // Sun-path-driven placement — configured from Flutter before plane detection.
    // Defaults ≈ central-India optimum (lat 20°) and 0.45 m (~1.5 ft) mounting height.
    private var panelTiltDeg = 18.3f      // SunPath.optimalTiltDeg(20)
    @Suppress("unused") private var panelAzimuthDeg = 180f
    private var panelElevationM = 0.45f

    var eventSink: EventChannel.EventSink? = null

    init {
        Log.e(TAG, "ARSceneManager.init")
        setupGLView()
        activity.lifecycle.addObserver(this)
        activity.registerComponentCallbacks(orientationCallback)
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
        emitCameraPermission("granted", false)
        createSession()
    }

    /**
     * Called from MainActivity when the user denies the camera permission.
     * `permanent = true` means the user chose "Don't ask again" — a second
     * in-app request will be ignored by the system, so Flutter should guide
     * the user to Settings instead of re-prompting.
     */
    fun onCameraPermissionDenied(permanent: Boolean) {
        Log.e(TAG, "onCameraPermissionDenied (permanent=$permanent)")
        emitCameraPermission("denied", permanent)
    }

    private fun emitCameraPermission(status: String, permanent: Boolean) {
        val sink = eventSink ?: return
        try {
            sink.success(mapOf(
                "cameraPermission" to status,
                "cameraPermissionPermanent" to permanent,
            ))
        } catch (_: Exception) {}
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
        Log.e(TAG, "placeGrid: ${positions.size} panels @ tilt=${panelTiltDeg}° elev=${panelElevationM}m")

        // Tilt quaternion: rotation around plane-local +X axis by panelTiltDeg.
        // In the panel geometry (lying flat at y=0, corners at ±hw,0,±hh),
        // a positive rotation about +X lifts the back edge (+z side) of the
        // panel upward, producing a sun-facing tilted module on a flat roof.
        val halfRad = Math.toRadians(panelTiltDeg.toDouble()) / 2.0
        val qx = Math.sin(halfRad).toFloat()
        val qw = Math.cos(halfRad).toFloat()
        val tiltPose = Pose.makeRotation(qx, 0f, 0f, qw)

        for (pos in positions) {
            try {
                // 1. Translate in plane-local frame (plane Y = world up),
                //    lifting the panel clear of the roof surface.
                // 2. Compose tilt rotation after translation so it rotates
                //    about the panel's own centre, not the plane origin.
                val local = Pose.makeTranslation(pos.x, panelElevationM, pos.z)
                    .compose(tiltPose)
                val anchor = plane.createAnchor(plane.centerPose.compose(local))
                panelAnchors += anchor
                renderer.addAnchor(anchor)
            } catch (e: Exception) {
                Log.e(TAG, "createAnchor: ${e.message}")
            }
        }
    }

    /**
     * Called from Flutter before plane detection to set the sun-path-optimal
     * pose for every panel placed on this scan. Safe to call repeatedly —
     * the next `placeGrid` picks the new values up. Values already placed
     * stay where they are until `resetScan` is invoked.
     */
    fun configurePanelPose(tiltDeg: Float, azimuthDeg: Float, elevationM: Float) {
        panelTiltDeg = tiltDeg.coerceIn(0f, 60f)
        panelAzimuthDeg = azimuthDeg
        panelElevationM = elevationM.coerceIn(0f, 2.5f)
        Log.e(TAG, "configurePanelPose: tilt=${panelTiltDeg}° az=${panelAzimuthDeg}° elev=${panelElevationM}m")
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
        try { activity.unregisterComponentCallbacks(orientationCallback) } catch (_: Exception) {}
        clearAnchors()
        try { glSurfaceView.onPause() } catch (_: Exception) {}
        session?.close(); session = null
    }
}
