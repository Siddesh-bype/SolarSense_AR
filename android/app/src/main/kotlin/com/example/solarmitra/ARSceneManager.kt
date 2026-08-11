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
import android.opengl.Matrix
import android.util.Log
import android.view.MotionEvent
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
import kotlin.math.sqrt

/**
 * ARCore + GLSurfaceView pipeline (Impeller-safe).
 *
 * Each module is an independent [Panel]: it can be tapped to select, dragged to
 * a new spot, resized, and raised anywhere from floor level to 12 m. Anchors sit
 * on the roof plane carrying yaw only — elevation and tilt are applied in the
 * renderer's model matrix, so the height slider costs nothing and never has to
 * recreate an anchor.
 *
 * ARCore's `update()` is single-threaded, so everything needing a [Frame]
 * (hit-testing a tap, a drag, or an obstacle box; grabbing a camera image) is
 * queued and consumed on the GL thread inside [onFrame].
 */
class ARSceneManager(
    private val activity: ComponentActivity,
    private val cameraPermLauncher: ActivityResultLauncher<String>,
) : PlatformView, DefaultLifecycleObserver {

    companion object {
        private const val TAG = "SolarMitra"
        private const val MAX_ELEVATION_M = 12.0f
        private const val OBSTACLE_SETBACK_M = 0.30f
        private const val TAP_SLOP_PX = 24f
        private const val DRAG_THROTTLE_MS = 90L

        /** Module catalogue offered to the mixed-size packer, largest first. */
        private val CATALOG = listOf(
            PanelGridCalculator.FlexSpec(2.00f, 1.30f, PanelLayout.AUTO), // 700 W
            PanelGridCalculator.FlexSpec(1.70f, 1.14f, PanelLayout.AUTO), // 540 W
            PanelGridCalculator.FlexSpec(1.60f, 1.00f, PanelLayout.AUTO), // 460 W
        )
    }

    private val rootView = FrameLayout(activity)
    private val glSurfaceView = GLSurfaceView(activity)
    private val renderer = ARRenderer(::onFrame, ::currentDisplayRotation)

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
    private var depthSeen = false
    private var lastHudEmittedMs = 0L

    // ── Panels ───────────────────────────────────────────────────────────────
    private val panelLock = Any()
    private val panels = mutableListOf<Panel>()
    private var nextPanelId = 1
    private var selectedId: Int? = null

    // ── Obstacles ────────────────────────────────────────────────────────────
    private val keepOuts = mutableListOf<KeepOut>()
    @Volatile private var pendingObstacles: List<Map<String, Any>>? = null

    // Sun-path-driven placement, configured from Flutter.
    private var panelTiltDeg = 18.3f
    private var panelAzimuthDeg = 180f
    private var panelElevationM = 0.45f

    private var panelSpec = PanelGridCalculator.FlexSpec(
        PanelGridCalculator.PANEL_W,
        PanelGridCalculator.PANEL_D,
        PanelLayout.AUTO,
    )
    private var lastPlaneCenter = floatArrayOf(0f, 0f, 0f)
    private var lastPlaneArea = 0f

    var eventSink: EventChannel.EventSink? = null

    // ── Compass ──────────────────────────────────────────────────────────────
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

    // ── Queued GL-thread work ────────────────────────────────────────────────
    private var pendingCapture = false
    private var pendingCaptureResult: MethodChannel.Result? = null
    @Volatile private var pendingDragX = -1f
    @Volatile private var pendingDragY = -1f
    private var lastDragHandledMs = 0L

    // Touch bookkeeping (UI thread).
    private var downX = 0f
    private var downY = 0f
    private var dragging = false
    private val vpScratch = FloatArray(16)
    private val vecIn = FloatArray(4)
    private val vecOut = FloatArray(4)

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
        // ARCore's renderer expects an 8-bit stencil; requesting 0 makes some
        // drivers hand back a config it cannot use.
        glSurfaceView.setEGLConfigChooser(8, 8, 8, 8, 16, 8)
        glSurfaceView.setRenderer(renderer)
        glSurfaceView.renderMode = GLSurfaceView.RENDERMODE_CONTINUOUSLY
        glSurfaceView.setOnTouchListener { _, e -> onTouch(e) }
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

    // ── Touch: tap to select, drag to move ───────────────────────────────────

    private fun onTouch(e: MotionEvent): Boolean {
        when (e.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                downX = e.x; downY = e.y
                dragging = false
                // Selecting on DOWN means a drag moves the panel you touched.
                val hit = panelNearScreen(e.x, e.y)
                synchronized(panelLock) {
                    panels.forEach { it.selected = false }
                    hit?.selected = true
                    selectedId = hit?.id
                }
                return true
            }
            MotionEvent.ACTION_MOVE -> {
                if (selectedId == null) return true
                if (!dragging &&
                    (kotlin.math.abs(e.x - downX) > TAP_SLOP_PX ||
                        kotlin.math.abs(e.y - downY) > TAP_SLOP_PX)
                ) dragging = true
                if (dragging) { pendingDragX = e.x; pendingDragY = e.y }
                return true
            }
            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                if (dragging) { pendingDragX = e.x; pendingDragY = e.y }
                dragging = false
                activity.runOnUiThread { streamHud() }
                return true
            }
        }
        return true
    }

    /** Nearest panel whose projected centre is within its own on-screen radius. */
    private fun panelNearScreen(sx: Float, sy: Float): Panel? {
        if (!renderer.copyViewProjection(vpScratch)) return null
        val w = glSurfaceView.width.toFloat()
        val h = glSurfaceView.height.toFloat()
        if (w <= 0f || h <= 0f) return null
        var best: Panel? = null
        var bestD = Float.MAX_VALUE
        synchronized(panelLock) {
            for (p in panels) {
                if (p.anchor.trackingState != TrackingState.TRACKING) continue
                val pose = p.anchor.pose
                vecIn[0] = pose.tx(); vecIn[1] = pose.ty() + p.elevationM
                vecIn[2] = pose.tz(); vecIn[3] = 1f
                Matrix.multiplyMV(vecOut, 0, vpScratch, 0, vecIn, 0)
                if (vecOut[3] <= 0f) continue
                val px = (vecOut[0] / vecOut[3] * 0.5f + 0.5f) * w
                val py = (1f - (vecOut[1] / vecOut[3] * 0.5f + 0.5f)) * h
                val d = (px - sx) * (px - sx) + (py - sy) * (py - sy)
                // Screen radius scales with distance: use the projected width of
                // the module as the touch target instead of a fixed pixel box.
                val radius = (w * 0.10f) + (p.widthM * 40f)
                if (d < bestD && d < radius * radius) { bestD = d; best = p }
            }
        }
        return best
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
        // ARCore's single-thread contract means every frame that needs one is
        // handled here — a throw must not kill the session, so everything is
        // guarded and logged instead.
        val s = session ?: return
        try {
            handlePlaneUpdate(frame, s)
            markDepthOnce(frame)
            if (pendingCapture) { pendingCapture = false; runCapture(frame) }
            streamHudThrottled()
        } catch (e: Exception) {
            Log.e(TAG, "onFrame recovered: ${e.message}", e)
        }
    }

    private fun handlePlaneUpdate(frame: Frame, s: Session) {
        if (pendingDragX >= 0f) {
            val now = android.os.SystemClock.elapsedRealtime()
            if (now - lastDragHandledMs >= DRAG_THROTTLE_MS) {
                lastDragHandledMs = now
                handleDrag(frame)
                pendingDragX = -1f; pendingDragY = -1f
            }
        }
        val pending = pendingObstacles
        if (pending != null) {
            pendingObstacles = null
            handleObstacles(frame, pending)
        }

        val allPlanes = s.getAllTrackables(Plane::class.java)
        val best = allPlanes
            .filter {
                it.type == Plane.Type.HORIZONTAL_UPWARD_FACING
                && it.trackingState == TrackingState.TRACKING
                && it.subsumedBy == null
            }
            .maxByOrNull { it.extentX * it.extentZ } ?: return

        val newArea = best.extentX * best.extentZ
        val center = best.centerPose.translation
        val delta = lastPlaneArea == 0f || newArea > lastPlaneArea * 1.05f ||
            distance(center, lastPlaneCenter) > 0.4f

        // Re-seed when the detected roof region grows or the phone is swept
        // across a larger area — but only when the user hasn't rearranged things
        // manually, so a deliberate layout survives.
        if (currentPlane == null || (delta && !anyPanelMoved)) {
            lastPlaneCenter = center.clone()
            lastPlaneArea = newArea
            activity.runOnUiThread { placeGrid(best) }
        }
    }

    private fun markDepthOnce(frame: Frame) {
        if (depthSeen) return
        try {
            frame.acquireDepthImage16Bits().use { depthSeen = true }
        } catch (_: Exception) { /* depth optional */ }
    }

    private fun streamHudThrottled() {
        val now = android.os.SystemClock.elapsedRealtime()
        if (now - lastHudEmittedMs >= 80) {
            lastHudEmittedMs = now
            activity.runOnUiThread { streamHud() }
        }
    }

    private fun distance(a: FloatArray, b: FloatArray): Float {
        val dx = a[0] - b[0]; val dy = a[1] - b[1]; val dz = a[2] - b[2]
        return sqrt(dx * dx + dy * dy + dz * dz)
    }

    // ── Hit testing ───────────────────────────────────────────────────────────

    private fun hitPlanePose(frame: Frame, x: Float, y: Float): Pose? {
        val plane = currentPlane ?: return null
        return try {
            frame.hitTest(x, y).firstOrNull { h ->
                plane.trackingState == TrackingState.TRACKING &&
                    h.trackable == plane && h.distance < 12f
            }?.hitPose
        } catch (_: Exception) { null }
    }

    /** Convert a world-space pose to plane-local XZ (plane centre = origin).
     *  Uses the plane pose's own inverse so the plane's yaw is accounted for. */
    private fun poseToLocal(pose: Pose, plane: Plane): Pair<Float, Float> {
        val local = plane.centerPose.inverse().compose(pose)
        return Pair(local.tx(), local.tz())
    }

    private fun handleDrag(frame: Frame) {
        val id = selectedId ?: return
        val plane = currentPlane ?: return
        val pose = hitPlanePose(frame, pendingDragX, pendingDragY) ?: return
        val (lx, lz) = poseToLocal(pose, plane)
        synchronized(panelLock) {
            val p = panels.firstOrNull { it.id == id } ?: return
            val newAnchor = try {
                plane.createAnchor(
                    plane.centerPose.compose(
                        Pose.makeTranslation(lx, 0f, lz)
                            .compose(yawPose(p.azimuthDeg)),
                    )
                )
            } catch (_: Exception) { return }
            p.anchor.detach()
            p.anchor = newAnchor
            p.localX = lx; p.localZ = lz
            p.moved = true
        }
    }

    private fun yawPose(yawDeg: Float): Pose {
        val half = Math.toRadians(yawDeg.toDouble()) / 2.0
        val qy = Math.sin(half).toFloat()
        val qw = Math.cos(half).toFloat()
        return Pose.makeRotation(0f, qy, 0f, qw)
    }

    // Tilt is applied by the renderer's model matrix, not the anchor, so
    // changing tilt or height never has to recreate an ARCore anchor.

    // ── Obstacles ────────────────────────────────────────────────────────────

    /** Ray-cast normalized detection boxes onto the plane as keep-out zones. */
    private fun handleObstacles(frame: Frame, boxes: List<Map<String, Any>>) {
        val plane = currentPlane ?: return
        if (plane.trackingState != TrackingState.TRACKING) return
        val newKeepOuts = mutableListOf<KeepOut>()
        val viewW = glSurfaceView.width.toFloat()
        val viewH = glSurfaceView.height.toFloat()
        if (viewW <= 0f || viewH <= 0f) return
        for (b in boxes) {
            val label = b["label"] as? String ?: continue
            val cx = (b["x"] as? Number)?.toFloat() ?: 0.5f
            val cy = (b["y"] as? Number)?.toFloat() ?: 0.5f
            val pose = hitPlanePose(frame, cx * viewW, cy * viewH) ?: continue
            val (lx, lz) = poseToLocal(pose, plane)
            // Footprint (m²) comes from Dart's ObstacleFootprint table, so the
            // physical estimates live in exactly one place.
            val footprint = (b["footprintM2"] as? Number)?.toFloat() ?: 1.0f
            val side = sqrt(footprint) + OBSTACLE_SETBACK_M
            newKeepOuts += KeepOut(lx, lz, side / 2f, side / 2f, label)
        }
        synchronized(panelLock) { keepOuts.clear(); keepOuts += newKeepOuts }
        glSurfaceView.queueEvent {
            renderer.setKeepOuts(newKeepOuts.toList(), planeMatrix())
        }
        // Panels already inside a keep-out render faded so the user sees the clash.
        synchronized(panelLock) {
            for (p in panels) {
                val hw = p.widthM / 2f; val hd = p.heightM / 2f
                p.occlusion = if (newKeepOuts.any { it.overlaps(p.localX, p.localZ, hw, hd) })
                    0.25f else 1.0f
            }
        }
        activity.runOnUiThread { streamHud() }
    }

    private fun planeMatrix(): FloatArray? {
        val plane = currentPlane ?: return null
        val m = FloatArray(16)
        plane.centerPose.toMatrix(m, 0)
        return m
    }

    private val anyPanelMoved: Boolean
        get() = synchronized(panelLock) { panels.any { it.moved } }

    // ── Grid ──────────────────────────────────────────────────────────────────

    /** Seed a fresh layout from the packer (kept for additive +/-, mixed sizes
     *  and obstacle keep-outs). Destroys any manual arrangement. */
    private fun placeGrid(plane: Plane) {
        clearAnchors()
        currentPlane = plane
        val placed = PanelGridCalculator.packMixed(plane, CATALOG, keepOuts.toList())
        synchronized(panelLock) {
            for (pl in placed) {
                try {
                    val anchor = plane.createAnchor(
                        plane.centerPose.compose(
                            Pose.makeTranslation(pl.x, 0f, pl.z).compose(yawPose(panelAzimuthDeg)),
                        )
                    )
                    panels += Panel(
                        id = nextPanelId++,
                        anchor = anchor,
                        widthM = pl.widthM,
                        heightM = pl.heightM,
                        elevationM = panelElevationM,
                        tiltDeg = panelTiltDeg,
                        azimuthDeg = panelAzimuthDeg,
                        localX = pl.x,
                        localZ = pl.z,
                    )
                } catch (e: Exception) {
                    Log.e(TAG, "createAnchor: ${e.message}")
                }
            }
        }
        pushPanelsToRenderer()
    }

    /** Rebuild every panel's anchor in place (single panel, or all). */
    private fun reanchor(pred: (Panel) -> Boolean) {
        val plane = currentPlane ?: return
        synchronized(panelLock) {
            for (p in panels) {
                if (!pred(p)) continue
                try {
                    val newAnchor = plane.createAnchor(
                        plane.centerPose.compose(
                            Pose.makeTranslation(p.localX, 0f, p.localZ)
                                .compose(yawPose(p.azimuthDeg)),
                        )
                    )
                    p.anchor.detach()
                    p.anchor = newAnchor
                    p.moved = true
                } catch (_: Exception) {}
            }
        }
        pushPanelsToRenderer()
    }

    private fun pushPanelsToRenderer() {
        synchronized(panelLock) { renderer.setPanels(panels.toList()) }
    }

    // ── Configure (from Flutter) ──────────────────────────────────────────────

    fun configurePanelPose(tiltDeg: Float, azimuthDeg: Float, elevationM: Float) {
        panelTiltDeg = tiltDeg.coerceIn(0f, 60f)
        panelAzimuthDeg = azimuthDeg
        panelElevationM = elevationM.coerceIn(0f, MAX_ELEVATION_M)
        // Apply to every panel the user hasn't hand-adjusted.
        synchronized(panelLock) {
            for (p in panels) {
                if (p.moved) continue
                p.tiltDeg = panelTiltDeg
                p.azimuthDeg = panelAzimuthDeg
                p.elevationM = panelElevationM
            }
        }
    }

    /** Switch the module size/orientation used for new panels and for the
     *  currently selected one (or all panels when nothing is selected). */
    fun configurePanelFlex(widthM: Float, heightM: Float, layout: String?) {
        val l = when (layout?.lowercase()) {
            "landscape" -> PanelLayout.LANDSCAPE
            "portrait"  -> PanelLayout.PORTRAIT
            else        -> PanelLayout.AUTO
        }
        val w = widthM.coerceIn(0.8f, 3.0f)
        val h = heightM.coerceIn(0.5f, 2.2f)
        panelSpec = PanelGridCalculator.FlexSpec(w, h, l)
        val (cw, ch) = when (l) {
            PanelLayout.PORTRAIT  -> Pair(minOf(w, h), maxOf(w, h))
            PanelLayout.LANDSCAPE -> Pair(maxOf(w, h), minOf(w, h))
            PanelLayout.AUTO      -> Pair(w, h)
        }
        setPanelSize(selectedId ?: 0, cw, ch)
    }

    fun setPanelHeight(id: Int, elevationM: Float) {
        val e = elevationM.coerceIn(0f, MAX_ELEVATION_M)
        val ids = if (id > 0) listOf(id) else synchronized(panelLock) { panels.map { it.id } }
        synchronized(panelLock) {
            for (p in panels) {
                if (p.id in ids) { p.elevationM = e; p.moved = true }
            }
        }
        activity.runOnUiThread { streamHud() }
    }

    /** Raise every panel to a shared height — the "floor vs roof" control. */
    fun setAllPanelHeight(elevationM: Float) {
        val e = elevationM.coerceIn(0f, MAX_ELEVATION_M)
        synchronized(panelLock) {
            for (p in panels) { p.elevationM = e; p.moved = true }
        }
        panelElevationM = e
        activity.runOnUiThread { streamHud() }
    }

    fun setPanelSize(id: Int, widthM: Float, heightM: Float) {
        val w = widthM.coerceIn(0.8f, 3.0f)
        val h = heightM.coerceIn(0.5f, 2.2f)
        synchronized(panelLock) {
            for (p in panels) {
                if (id > 0 && p.id != id) continue
                p.widthM = w; p.heightM = h
                p.moved = true
            }
        }
        pushPanelsToRenderer()
        activity.runOnUiThread { streamHud() }
    }

    fun deletePanel(id: Int) {
        synchronized(panelLock) {
            val p = panels.firstOrNull { it.id == id } ?: return
            p.anchor.detach()
            panels.remove(p)
            if (selectedId == id) selectedId = null
        }
        pushPanelsToRenderer()
        activity.runOnUiThread { streamHud() }
    }

    fun addPanel() {
        val plane = currentPlane ?: return
        synchronized(panelLock) {
            if (panels.size >= 24) return
            val spec = panelSpec
            // Place the next panel near the array centre, offset slightly so it
            // never overlaps an existing one.
            var px = 0f; var pz = 0f; var tries = 0
            do {
                val ring = (tries / 4) * (spec.widthM + 0.12f)
                val angle = (tries % 4) * (Math.PI / 2).toFloat()
                px = ring * Math.cos(angle.toDouble()).toFloat()
                pz = ring * Math.sin(angle.toDouble()).toFloat()
                tries++
            } while (tries < 32 && panels.any {
                kotlin.math.abs(it.localX - px) < spec.widthM / 2f &&
                    kotlin.math.abs(it.localZ - pz) < spec.heightM / 2f
            })
            try {
                val anchor = plane.createAnchor(
                    plane.centerPose.compose(
                        Pose.makeTranslation(px, 0f, pz).compose(yawPose(panelAzimuthDeg)),
                    )
                )
                panels += Panel(
                    id = nextPanelId++,
                    anchor = anchor,
                    widthM = spec.widthM,
                    heightM = spec.heightM,
                    elevationM = panelElevationM,
                    tiltDeg = panelTiltDeg,
                    azimuthDeg = panelAzimuthDeg,
                    localX = px,
                    localZ = pz,
                )
            } catch (e: Exception) {
                Log.e(TAG, "addPanel: ${e.message}")
            }
        }
        pushPanelsToRenderer()
        activity.runOnUiThread { streamHud() }
    }

    fun removePanel() {
        synchronized(panelLock) {
            if (panels.size <= 1) return
            val p = panels.last()
            p.anchor.detach()
            panels.remove(p)
            if (selectedId == p.id) selectedId = null
        }
        pushPanelsToRenderer()
        activity.runOnUiThread { streamHud() }
    }

    fun resetScan() {
        clearAnchors()
        currentPlane = null
        pendingObstacles = null
    }

    /** Replace the whole array with the mixed-size auto-packing of the plane. */
    fun autoFillMixed() {
        val plane = currentPlane ?: return
        clearAnchors()
        placeGrid(plane)
    }

    private fun clearAnchors() {
        synchronized(panelLock) {
            panels.forEach { it.anchor.detach() }
            panels.clear()
            selectedId = null
        }
        renderer.clearScene()
    }

    /** Request a JPEG snapshot of the current AR frame. Delivered async once the
     *  next GL frame is captured. */
    fun requestCapture(result: MethodChannel.Result) {
        pendingCaptureResult = result
        pendingCapture = true
    }

    /** Queue obstacle boxes (normalized image coords) from Dart; they are
     *  ray-cast onto the plane on the next GL frame. */
    fun applyObstacles(boxes: List<Map<String, Any>>) {
        pendingObstacles = boxes
    }

    private fun runCapture(frame: Frame) {
        val result = pendingCaptureResult
        pendingCaptureResult = null
        var image: Image? = null
        try {
            image = frame.acquireCameraImage()
            val w = image.width; val h = image.height
            val jpeg = yuv420ToJpeg(image)
            val r = result
            activity.runOnUiThread { r?.success(mapOf("bytes" to jpeg, "width" to w, "height" to h)) }
        } catch (e: Exception) {
            Log.e(TAG, "capture FAILED: ${e.message}")
            val r = result
            activity.runOnUiThread { r?.error("CAPTURE_FAILED", e.message, null) }
        } finally {
            // Exactly one image was acquired; always close it. Closing a second
            // image here used to wedge the ARCore session on devices whose camera
            // reports NV21-style planes.
            try { image?.close() } catch (_: Exception) {}
        }
    }

    /** Converts a YUV_420_888 frame to NV21. Respects per-plane pixel/row stride
     *  (handles both tightly-packed I420 and interleaved NV21-style layouts). */
    private fun yuv420ToJpeg(image: Image): ByteArray {
        val w = image.width; val h = image.height
        val yPlane = image.planes[0]
        val uPlane = image.planes[1]
        val vPlane = image.planes[2]

        val ySize = w * h
        val nv21 = ByteArray(ySize + w * h / 2)
        val yBuf = yPlane.buffer
        for (row in 0 until h) {
            yBuf.position(row * yPlane.rowStride)
            yBuf.get(nv21, row * w, w)
        }

        val uvH = h / 2
        var pos = ySize
        for (row in 0 until uvH) {
            for (col in 0 until w / 2) {
                nv21[pos++] = vPlane.buffer.get(
                    row * vPlane.rowStride + col * vPlane.pixelStride,
                )
                nv21[pos++] = uPlane.buffer.get(
                    row * uPlane.rowStride + col * uPlane.pixelStride,
                )
            }
        }

        val out = ByteArrayOutputStream()
        YuvImage(nv21, ImageFormat.NV21, w, h, null)
            .compressToJpeg(Rect(0, 0, w, h), 85, out)
        return out.toByteArray()
    }

    // ── Snapshots / HUD ───────────────────────────────────────────────────────

    fun getScanSnapshot(): Map<String, Any> {
        val a = ((currentPlane?.extentX ?: 0f) * (currentPlane?.extentZ ?: 0f)).toDouble()
        return synchronized(panelLock) {
            mapOf(
                "panelCount" to panels.size,
                "systemKw" to panels.sumOf { it.kw },
                "areaSqm" to a,
                "planeFound" to (currentPlane != null),
                "headingDeg" to headingDeg.toDouble(),
            )
        }
    }

    private fun streamHud() {
        val sink = eventSink ?: return
        val a = ((currentPlane?.extentX ?: 0f) * (currentPlane?.extentZ ?: 0f)).toDouble()
        try {
            val snapshot = synchronized(panelLock) {
                mapOf(
                    "panelCount" to panels.size,
                    "systemKw" to panels.sumOf { it.kw },
                    "maxPanels" to PanelGridCalculator.maxPanelsFor(a.toFloat(), panelSpec),
                    "selectedPanelId" to (selectedId ?: -1),
                )
            }
            sink.success(snapshot + mapOf(
                "areaSqm" to a,
                "planeFound" to (currentPlane != null),
                "headingDeg" to headingDeg.toDouble(),
                "depthAvailable" to depthSeen,
                "trackingState" to (if (currentPlane != null) "tracking" else "searching"),
                "occludedPanelCount" to synchronized(panelLock) { panels.count { it.occlusion < 0.9f } },
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

