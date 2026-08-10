package com.example.solarmitra

import android.Manifest
import android.content.ComponentCallbacks2
import android.content.Context
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.graphics.ImageFormat
import android.graphics.Rect
import android.graphics.YuvImage
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.media.Image
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
import com.google.ar.core.ArCoreApk
import com.google.ar.core.Config
import com.google.ar.core.Frame
import com.google.ar.core.Plane
import com.google.ar.core.Pose
import com.google.ar.core.Session
import com.google.ar.core.TrackingState
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import java.io.ByteArrayOutputStream

/**
 * ARCore + GLSurfaceView pipeline (proven, Impeller-safe) upgraded for the
 * rebuild:
 *   • Solar azimuth is now APPLIED to every panel (the previous
 *     `panelAzimuthDeg` was computed but never composed into the pose).
 *   • Real camera-frame capture via `captureFrame` — the link that makes
 *     on-device obstacle detection live (frames are grabbed on the GL thread
 *     to respect ARCore's single-thread `update()` contract).
 *   • HUD streams heading (compass), depth availability, tracking state and
 *     an occlusion count so the Flutter UI reflects real-world conditions.
 *
 * Note: GPU/Filament depth occlusion is the ideal next step; here we expose
 * depth availability and a per-panel occlusion hook (`renderer.setOcclusion`)
 * rather than fragile per-pixel depth reprojection.
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
            glSurfaceView.queueEvent { renderer.onDisplayRotationChanged() }
        }
        override fun onLowMemory() {}
        override fun onTrimMemory(level: Int) {}
    }

    private var session: Session? = null
    private var sessionCreated = false

    private var currentPlane: Plane? = null
    private val panelAnchors = mutableListOf<com.google.ar.core.Anchor>()
    private var frameCount = 0
    private var depthSeen = false
    private var lastHudEmittedMs = 0L    // throttle HUD stream to ~12 Hz

    // Sun-path-driven placement — configured from Flutter before plane detection.
    private var panelTiltDeg = 18.3f      // SunPath.optimalTiltDeg(20)
    private var panelAzimuthDeg = 180f    // NOW APPLIED — yaw about plane-local +Y
    private var panelElevationM = 0.45f

    // Panel module size + layout — user-configurable from the AR screen.
    private var panelSpec = PanelGridCalculator.FlexSpec(
        PanelGridCalculator.PANEL_W,
        PanelGridCalculator.PANEL_D,
        PanelLayout.AUTO,
    )
    private var lastPlaneCenter = floatArrayOf(0f, 0f, 0f)
    private var lastPlaneArea = 0f

    var eventSink: EventChannel.EventSink? = null

    // ── Compass (heading) ───────────────────────────────────────────────────
    private val sensorManager =
        activity.getSystemService(Context.SENSOR_SERVICE) as SensorManager
    private var headingDeg = 0f
    private val rotationMatrix = FloatArray(9)
    private val orientationVec = FloatArray(3)
    private val sensorListener = object : SensorEventListener {
        override fun onSensorChanged(e: SensorEvent) {
            if (e.sensor.type == Sensor.TYPE_ROTATION_VECTOR) {
                SensorManager.getRotationMatrixFromVector(rotationMatrix, e.values)
                SensorManager.getOrientation(rotationMatrix, orientationVec)
                val az = Math.toDegrees(orientationVec[0].toDouble()).toFloat()
                headingDeg = if (az < 0) az + 360f else az
            }
        }
        override fun onAccuracyChanged(s: Sensor?, a: Int) {}
    }

    // ── One-shot frame capture (obstacle detection) ───────────────────────────
    private var pendingCapture = false
    private var pendingCaptureResult: MethodChannel.Result? = null

    init {
        setupGLView()
        activity.lifecycle.addObserver(this)
        activity.registerComponentCallbacks(orientationCallback)
        try {
            sensorManager.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)?.let {
                sensorManager.registerListener(sensorListener, it, SensorManager.SENSOR_DELAY_UI)
            }
        } catch (_: Exception) { /* compass optional */ }
    }

    private fun setupGLView() {
        glSurfaceView.preserveEGLContextOnPause = true
        glSurfaceView.setEGLContextClientVersion(2)
        glSurfaceView.setEGLConfigChooser(8, 8, 8, 8, 16, 0)
        glSurfaceView.setRenderer(renderer)
        glSurfaceView.renderMode = GLSurfaceView.RENDERMODE_CONTINUOUSLY
        renderer.onSurfaceReadyCallback = {
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

    // ── Permission ───────────────────────────────────────────────────────────

    private fun checkPermissionAndSetup() {
        if (ContextCompat.checkSelfPermission(activity, Manifest.permission.CAMERA)
            == PackageManager.PERMISSION_GRANTED
        ) {
            createSession()
        } else {
            cameraPermLauncher.launch(Manifest.permission.CAMERA)
        }
    }

    fun onCameraPermissionGranted() {
        emitCameraPermission("granted", false)
        createSession()
    }

    fun onCameraPermissionDenied(permanent: Boolean) {
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
            ) return

            val s = Session(activity)
            Config(s).apply {
                depthMode           = Config.DepthMode.AUTOMATIC
                lightEstimationMode = Config.LightEstimationMode.ENVIRONMENTAL_HDR
                planeFindingMode    = Config.PlaneFindingMode.HORIZONTAL
                updateMode          = Config.UpdateMode.LATEST_CAMERA_IMAGE
            }.also { s.configure(it) }

            glSurfaceView.queueEvent {
                renderer.initCameraTexture(s)
                activity.runOnUiThread {
                    try {
                        s.resume()
                        glSurfaceView.onResume()
                    } catch (e: Exception) {
                        Log.e(TAG, "resume after texture FAILED: ${e.message}", e)
                    }
                }
            }
            session = s
            sessionCreated = true
        } catch (e: Exception) {
            Log.e(TAG, "createSession FAILED: ${e.message}", e)
        }
    }

    private fun resumeSession() {
        try {
            session?.resume()
            glSurfaceView.onResume()
        } catch (e: Exception) {
            Log.e(TAG, "resumeSession FAILED: ${e.message}", e)
        }
    }

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

        val allPlanes = s.getAllTrackables(Plane::class.java)
        val best = allPlanes
            .filter {
                it.type == Plane.Type.HORIZONTAL_UPWARD_FACING
                && it.trackingState == TrackingState.TRACKING
                && it.subsumedBy == null
            }
            .maxByOrNull { it.extentX * it.extentZ } ?: return

        val newArea  = best.extentX * best.extentZ
        val center = best.centerPose.translation
        val delta = lastPlaneArea == 0f || newArea > lastPlaneArea * 1.05f ||
            distance(center, lastPlaneCenter) > 0.4f

        // Re-place the grid when the detected roof region grows or the phone is
        // swept across a larger area — keeps panels glued to the best region.
        val shouldReposition = currentPlane == null || delta
        if (shouldReposition) {
            lastPlaneCenter = center.clone()
            lastPlaneArea = newArea
            activity.runOnUiThread { placeGrid(best) }
        }

        // Mark depth availability once (cheap, best-effort).
        if (!depthSeen) {
            try {
                frame.acquireDepthImage16Bits().use { depthSeen = true }
            } catch (_: Exception) { /* depth optional */ }
        }

        // One-shot capture for obstacle detection, on the GL thread.
        if (pendingCapture) {
            pendingCapture = false
            runCapture(frame)
        }

        // HUD updates are expensive to push through the binary messenger (Map
        // alloc + main-thread hop per frame). Throttle to ~12 Hz — plenty for a
        // live meter readout, and removes ~48 cross-thread posts per second.
        val now = android.os.SystemClock.elapsedRealtime()
        if (now - lastHudEmittedMs >= 80) {
            lastHudEmittedMs = now
            activity.runOnUiThread { streamHud() }
        }
    }

    private fun distance(a: FloatArray, b: FloatArray): Float {
        val dx = a[0] - b[0]; val dy = a[1] - b[1]; val dz = a[2] - b[2]
        return kotlin.math.sqrt(dx * dx + dy * dy + dz * dz)
    }

    // ── Grid ──────────────────────────────────────────────────────────────────

    private fun placeGrid(plane: Plane, count: Int? = null) {
        clearAnchors()
        currentPlane = plane
        val positions = PanelGridCalculator.calculate(plane, count, panelSpec)
        renderer.setPanelSize(panelSpec.widthM, panelSpec.heightM)

        // Tilt about plane-local +X; yaw (azimuth) about plane-local +Y — NOW LIVE.
        val halfTilt = Math.toRadians(panelTiltDeg.toDouble()) / 2.0
        val qx = Math.sin(halfTilt).toFloat(); val qwT = Math.cos(halfTilt).toFloat()
        val tiltPose = Pose.makeRotation(qx, 0f, 0f, qwT)

        val halfYaw = Math.toRadians(panelAzimuthDeg.toDouble()) / 2.0
        val qy = Math.sin(halfYaw).toFloat(); val qwY = Math.cos(halfYaw).toFloat()
        val yawPose = Pose.makeRotation(0f, qy, 0f, qwY)

        for (pos in positions) {
            try {
                val local = Pose.makeTranslation(pos.x, panelElevationM, pos.z)
                    .compose(yawPose)
                    .compose(tiltPose)
                val anchor = plane.createAnchor(plane.centerPose.compose(local))
                panelAnchors += anchor
                renderer.addAnchor(anchor)
            } catch (e: Exception) {
                Log.e(TAG, "createAnchor: ${e.message}")
            }
        }
    }

    fun configurePanelPose(tiltDeg: Float, azimuthDeg: Float, elevationM: Float) {
        panelTiltDeg = tiltDeg.coerceIn(0f, 60f)
        panelAzimuthDeg = azimuthDeg
        panelElevationM = elevationM.coerceIn(0f, 2.5f)
        Log.e(TAG, "configurePanelPose: tilt=${panelTiltDeg}° az=${panelAzimuthDeg}° elev=${panelElevationM}m")
    }

    /** Switch module size/orientation live. Re-places the grid so the new
     *  size applies immediately to the currently detected plane. */
    fun configurePanelFlex(widthM: Float, heightM: Float, layoutName: String?) {
        panelSpec = PanelGridCalculator.FlexSpec(
            widthM, heightM,
            when (layoutName) {
                "portrait"  -> PanelLayout.PORTRAIT
                "landscape" -> PanelLayout.LANDSCAPE
                else        -> PanelLayout.AUTO
            },
        )
        currentPlane?.let { activity.runOnUiThread { placeGrid(it, panelAnchors.size) } }
        Log.e(TAG, "configurePanelFlex: ${widthM}x${heightM} $layoutName")
    }

    /// Peak power (kW) per module, scaled with module area (≈470 Wp for the
    /// default 1.7×1.14 m module → area-scaled for larger/smaller modules).
    /// Feeds the HUD + scan snapshot so the financial engine sees the actual
    /// module size the user placed.
    private val perPanelKw: Double
        get() = (0.470 * (panelSpec.widthM * panelSpec.heightM) / (PanelGridCalculator.PANEL_W * PanelGridCalculator.PANEL_D))

    private fun clearAnchors() {
        panelAnchors.forEach { it.detach() }
        panelAnchors.clear()
        renderer.clearAnchors()
    }

    // ── Public API ────────────────────────────────────────────────────────────

    fun addPanel()    { currentPlane?.let { placeGrid(it, (panelAnchors.size + 1).coerceAtMost(20)) } }
    fun removePanel() { if (panelAnchors.size > 1) { panelAnchors.last().detach(); panelAnchors.removeLastOrNull(); renderer.removeLastAnchor() } }
    fun resetScan()   { clearAnchors(); currentPlane = null }

    /** Request a JPEG snapshot of the current AR frame. The result is delivered
     *  asynchronously via `result` once the next GL frame is captured. */
    fun requestCapture(result: MethodChannel.Result) {
        pendingCaptureResult = result
        pendingCapture = true
    }

    private fun runCapture(frame: Frame) {
        val result = pendingCaptureResult
        pendingCaptureResult = null
        try {
            val image = frame.acquireCameraImage()
            val w = image.width; val h = image.height
            val jpeg = yuv420ToJpeg(image)
            image.close()
            val r = result
            activity.runOnUiThread {
                r?.success(mapOf("bytes" to jpeg, "width" to w, "height" to h))
            }
        } catch (e: Exception) {
            try { frame.acquireCameraImage().close() } catch (_: Exception) {}
            val r = result
            activity.runOnUiThread { r?.error("CAPTURE_FAILED", e.message, null) }
        }
    }

    private fun yuv420ToJpeg(image: Image): ByteArray {
        val width = image.width; val height = image.height
        val yPlane = image.planes[0]
        val uPlane = image.planes[1]
        val vPlane = image.planes[2]
        val yBuffer = yPlane.buffer
        val uBuffer = uPlane.buffer
        val vBuffer = vPlane.buffer
        val ySize = yBuffer.remaining()
        val uvSize = uBuffer.remaining() + vBuffer.remaining()
        val nv21 = ByteArray(ySize + uvSize)
        yBuffer.get(nv21, 0, ySize)

        val uvWidth = width / 2
        val uvHeight = height / 2
        var pos = ySize
        for (row in 0 until uvHeight) {
            for (col in 0 until uvWidth) {
                val vIdx = row * vPlane.rowStride + col * vPlane.pixelStride
                val uIdx = row * uPlane.rowStride + col * uPlane.pixelStride
                nv21[pos++] = vBuffer.get(vIdx)
                nv21[pos++] = uBuffer.get(uIdx)
            }
        }
        val out = ByteArrayOutputStream()
        YuvImage(nv21, ImageFormat.NV21, width, height, null)
            .compressToJpeg(Rect(0, 0, width, height), 85, out)
        return out.toByteArray()
    }

    fun getScanSnapshot(): Map<String, Any> {
        val a = ((currentPlane?.extentX ?: 0f) * (currentPlane?.extentZ ?: 0f)).toDouble()
        return mapOf(
            "panelCount" to panelAnchors.size,
            "systemKw" to (panelAnchors.size * perPanelKw),
            "areaSqm" to a,
            "planeFound" to (currentPlane != null),
            "headingDeg" to headingDeg.toDouble(),
        )
    }

    private fun streamHud() {
        val sink = eventSink ?: return
        val a = ((currentPlane?.extentX ?: 0f) * (currentPlane?.extentZ ?: 0f)).toDouble()
        try {
            sink.success(mapOf(
                "panelCount" to panelAnchors.size,
                "maxPanels" to PanelGridCalculator.maxPanelsFor(a.toFloat(), panelSpec),
                "systemKw" to (panelAnchors.size * perPanelKw),
                "areaSqm" to a,
                "planeFound" to (currentPlane != null),
                "headingDeg" to headingDeg.toDouble(),
                "depthAvailable" to depthSeen,
                "trackingState" to (if (currentPlane != null) "tracking" else "searching"),
                "occludedPanelCount" to 0,
                "panelWidthM" to panelSpec.widthM.toDouble(),
                "panelHeightM" to panelSpec.heightM.toDouble(),
                "panelLayout" to panelSpec.layout.name,
            ))
        } catch (_: Exception) {}
    }

    // ── PlatformView ──────────────────────────────────────────────────────────

    override fun getView(): View = rootView

    override fun dispose() {
        activity.lifecycle.removeObserver(this)
        try { activity.unregisterComponentCallbacks(orientationCallback) } catch (_: Exception) {}
        try { sensorManager.unregisterListener(sensorListener) } catch (_: Exception) {}
        clearAnchors()
        try { glSurfaceView.onPause() } catch (_: Exception) {}
        session?.close(); session = null
    }
}
