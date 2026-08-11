package com.example.solarmitra

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.opengl.GLES20
import android.opengl.GLUtils
import android.opengl.Matrix
import android.util.Log
import android.view.Surface
import com.google.ar.core.Coordinates2d
import com.google.ar.core.Frame
import com.google.ar.core.Session
import com.google.ar.core.TrackingState
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer
import javax.microedition.khronos.egl.EGLConfig
import javax.microedition.khronos.opengles.GL10
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.roundToInt
import kotlin.math.sin

/**
 * Raw OpenGL ES 2.0 renderer for the ARCore camera feed + 3D solar panels.
 *
 * Each [Panel] is drawn as an extruded module (silver bezel, textured PV glass
 * top, 4 side walls, trim ring) sitting on a mounting structure of 2 rails and
 * 4 legs that reach down to the roof plane. Panels are independent: size,
 * height, tilt and selection are per-panel, so several module sizes coexist.
 *
 * Geometry is cached per distinct size (module) and per distinct
 * size+height+tilt (mount), so a mixed-size array costs no per-frame rebuilds.
 *
 * Every vertex attribute is bound to a buffer with enough elements for the draw
 * that follows. Android's GLES20 wrapper bounds-checks client-side arrays
 * against `remaining()` and throws from `glDrawArrays` if a draw reads past the
 * end — which on the GL thread silently kills all rendering.
 */
class ARRenderer(
    private val onFrameCallback: (Frame) -> Unit,
    private val rotationSupplier: () -> Int = { Surface.ROTATION_0 },
) : android.opengl.GLSurfaceView.Renderer {

    companion object {
        private const val TAG = "SolarMitra"
        private val SIDE_COLOR    = floatArrayOf(0.05f, 0.10f, 0.24f, 1.00f)
        private val FRAME_COLOR   = floatArrayOf(0.72f, 0.75f, 0.79f, 1.00f)
        private val MOUNT_COLOR   = floatArrayOf(0.58f, 0.62f, 0.67f, 1.00f)
        private val SELECT_COLOR  = floatArrayOf(0.98f, 0.75f, 0.14f, 1.00f) // gold
        private val KEEPOUT_COLOR = floatArrayOf(0.95f, 0.26f, 0.21f, 0.90f) // red
        private const val THICK = 0.06f      // module box thickness (m)

        private const val MOUNT_BAR = 0.022f // half-thickness of rails/legs (m)
        private const val RAIL_FRAC = 0.55f  // rail position, fraction of half-depth
        private const val LEG_FRAC  = 0.75f  // leg position, fraction of half-width
    }

    var onSurfaceReadyCallback: (() -> Unit)? = null

    private var session: Session? = null
    private val cameraTexId = IntArray(1)
    private var panelTexId = 0

    /** Panels are owned by [ARSceneManager]; the renderer only reads them.
     *  Structural changes are pushed via [setPanels] under the monitor; in-place
     *  field edits (selected, elevationM, occlusion) are seen on the next frame. */
    private var panels: List<Panel> = emptyList()
    private var keepOuts: List<KeepOut> = emptyList()
    private var planeMatrix: FloatArray? = null

    private var viewportWidth = 0
    private var viewportHeight = 0
    @Volatile private var pendingRotationUpdate = false

    private var bgProgram = 0
    private var objProgram = 0

    private val projMatrix = FloatArray(16)
    private val viewMatrix = FloatArray(16)
    private val vpMatrix = FloatArray(16)
    private val modelMatrix = FloatArray(16)
    private val mvpMatrix = FloatArray(16)
    private val scratchMatrix = FloatArray(16)

    // ── Geometry caches ──────────────────────────────────────────────────────
    private class ModuleGeom(
        val top: FloatBuffer, val topUV: FloatBuffer,
        val side: FloatBuffer, val sideCount: Int,
        val trim: FloatBuffer,
    )
    private class MountGeom(val verts: FloatBuffer, val count: Int)

    private val moduleCache = HashMap<Long, ModuleGeom>()
    private val mountCache  = HashMap<Long, MountGeom>()

    /** Zero-filled UVs bound during untextured draws so the UV attribute always
     *  has at least as many elements as the position attribute. */
    private lateinit var zeroUVs: FloatBuffer
    private lateinit var ringBuf: FloatBuffer   // reused 4-corner keep-out ring

    // Camera background quad.
    private val quadCoords = floatArrayOf(-1f, -1f, 1f, -1f, -1f, 1f, 1f, 1f)
    private val quadUVs    = floatArrayOf(0f, 1f, 1f, 1f, 0f, 0f, 1f, 0f)
    private lateinit var quadCoordsBuffer: FloatBuffer
    private lateinit var quadUVsBuffer: FloatBuffer

    // ── State pushed from ARSceneManager ─────────────────────────────────────

    @Synchronized fun setPanels(list: List<Panel>) { panels = list }

    @Synchronized fun setKeepOuts(list: List<KeepOut>, planePose: FloatArray?) {
        keepOuts = list
        planeMatrix = planePose
    }

    @Synchronized fun clearScene() {
        panels = emptyList()
        keepOuts = emptyList()
        planeMatrix = null
    }

    /** Latest view-projection, for screen-space hit testing on the UI thread. */
    @Synchronized fun copyViewProjection(out: FloatArray): Boolean {
        if (viewportWidth == 0) return false
        System.arraycopy(vpMatrix, 0, out, 0, 16)
        return true
    }

    fun initCameraTexture(s: Session) {
        val oes = 0x8D65
        GLES20.glGenTextures(1, cameraTexId, 0)
        GLES20.glBindTexture(oes, cameraTexId[0])
        GLES20.glTexParameteri(oes, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE)
        GLES20.glTexParameteri(oes, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE)
        GLES20.glTexParameteri(oes, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_NEAREST)
        GLES20.glTexParameteri(oes, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_NEAREST)
        s.setCameraTextureName(cameraTexId[0])
        if (viewportWidth > 0 && viewportHeight > 0) {
            s.setDisplayGeometry(rotationSupplier(), viewportWidth, viewportHeight)
        }
        session = s
        pendingRotationUpdate = true
    }

    fun onDisplayRotationChanged() {
        pendingRotationUpdate = true
        if (viewportWidth > 0 && viewportHeight > 0) {
            session?.setDisplayGeometry(rotationSupplier(), viewportWidth, viewportHeight)
        }
    }

    // ── GLSurfaceView.Renderer ───────────────────────────────────────────────

    override fun onSurfaceCreated(gl: GL10?, config: EGLConfig?) {
        GLES20.glClearColor(0f, 0f, 0f, 1f)
        bgProgram  = buildProgram(BG_VERT, BG_FRAG)
        objProgram = buildProgram(OBJ_VERT, OBJ_FRAG)
        quadCoordsBuffer = buf(quadCoords)
        quadUVsBuffer    = buf(quadUVs)
        zeroUVs = buf(FloatArray(1024))
        ringBuf = buf(FloatArray(12))
        panelTexId = buildSolarPanelTexture()
        moduleCache.clear()
        mountCache.clear()
        onSurfaceReadyCallback?.invoke()
    }

    override fun onSurfaceChanged(gl: GL10?, w: Int, h: Int) {
        viewportWidth = w; viewportHeight = h
        GLES20.glViewport(0, 0, w, h)
        session?.setDisplayGeometry(rotationSupplier(), w, h)
        pendingRotationUpdate = true
    }

    override fun onDrawFrame(gl: GL10?) {
        GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT or GLES20.GL_DEPTH_BUFFER_BIT)
        val s = session ?: return
        val frame = try { s.update() } catch (_: Exception) { return }

        // A single bad frame must never permanently blank the scene: anything
        // thrown here would otherwise kill the GL thread for good.
        try {
            if (frame.hasDisplayGeometryChanged() || pendingRotationUpdate) {
                frame.transformCoordinates2d(
                    Coordinates2d.OPENGL_NORMALIZED_DEVICE_COORDINATES, quadCoordsBuffer,
                    Coordinates2d.TEXTURE_NORMALIZED, quadUVsBuffer,
                )
                pendingRotationUpdate = false
            }
            drawBackground()
            frame.camera.getProjectionMatrix(projMatrix, 0, 0.1f, 100f)
            frame.camera.getViewMatrix(viewMatrix, 0)
            synchronized(this) {
                Matrix.multiplyMM(vpMatrix, 0, projMatrix, 0, viewMatrix, 0)
            }
            onFrameCallback(frame)
            if (frame.camera.trackingState == TrackingState.TRACKING) {
                synchronized(this) {
                    drawKeepOuts()
                    drawPanels()
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "onDrawFrame recovered: ${e.message}", e)
        }
    }

    private fun drawBackground() {
        GLES20.glDisable(GLES20.GL_DEPTH_TEST)
        GLES20.glDepthMask(false)
        GLES20.glUseProgram(bgProgram)
        val posLoc = GLES20.glGetAttribLocation(bgProgram, "a_Position")
        val uvLoc  = GLES20.glGetAttribLocation(bgProgram, "a_TexCoord")
        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(0x8D65, cameraTexId[0])
        GLES20.glUniform1i(GLES20.glGetUniformLocation(bgProgram, "u_Texture"), 0)
        GLES20.glEnableVertexAttribArray(posLoc)
        GLES20.glVertexAttribPointer(posLoc, 2, GLES20.GL_FLOAT, false, 0, quadCoordsBuffer)
        GLES20.glEnableVertexAttribArray(uvLoc)
        GLES20.glVertexAttribPointer(uvLoc, 2, GLES20.GL_FLOAT, false, 0, quadUVsBuffer)
        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
        GLES20.glDisableVertexAttribArray(posLoc)
        GLES20.glDisableVertexAttribArray(uvLoc)
        GLES20.glEnable(GLES20.GL_DEPTH_TEST)
        GLES20.glDepthMask(true)
    }

    private fun drawPanels() {
        if (panels.isEmpty()) return
        GLES20.glUseProgram(objProgram)
        GLES20.glEnable(GLES20.GL_BLEND)
        GLES20.glBlendFunc(GLES20.GL_SRC_ALPHA, GLES20.GL_ONE_MINUS_SRC_ALPHA)
        GLES20.glEnable(GLES20.GL_DEPTH_TEST)
        GLES20.glDepthMask(false) // panels blend against the camera feed

        val mvpLoc    = GLES20.glGetUniformLocation(objProgram, "u_MVP")
        val colorLoc  = GLES20.glGetUniformLocation(objProgram, "u_Color")
        val posLoc    = GLES20.glGetAttribLocation(objProgram, "a_Position")
        val uvLoc     = GLES20.glGetAttribLocation(objProgram, "a_TexCoord")
        val useTexLoc = GLES20.glGetUniformLocation(objProgram, "u_useTexture")

        GLES20.glActiveTexture(GLES20.GL_TEXTURE1)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, panelTexId)
        GLES20.glUniform1i(GLES20.glGetUniformLocation(objProgram, "u_Texture"), 1)
        GLES20.glEnableVertexAttribArray(posLoc)
        GLES20.glEnableVertexAttribArray(uvLoc)

        for (p in panels) {
            if (p.anchor.trackingState != TrackingState.TRACKING) continue
            val alpha = p.occlusion
            val module = moduleFor(p.widthM, p.heightM)
            val mount  = mountFor(p.widthM, p.heightM, p.elevationM, p.tiltDeg)

            // The anchor sits on the roof plane carrying yaw only, so mount
            // geometry uses it directly: +Y is the plane normal, roof at y = 0.
            p.anchor.pose.toMatrix(modelMatrix, 0)

            // 1) Mounting rails + legs, in the untilted anchor frame.
            Matrix.multiplyMM(mvpMatrix, 0, vpMatrix, 0, modelMatrix, 0)
            GLES20.glUniformMatrix4fv(mvpLoc, 1, false, mvpMatrix, 0)
            GLES20.glUniform1i(useTexLoc, 0)
            GLES20.glUniform4fv(colorLoc, 1, tint(MOUNT_COLOR, alpha), 0)
            GLES20.glVertexAttribPointer(posLoc, 3, GLES20.GL_FLOAT, false, 0, mount.verts)
            GLES20.glVertexAttribPointer(uvLoc, 2, GLES20.GL_FLOAT, false, 0, zeroUVs)
            GLES20.glDrawArrays(GLES20.GL_TRIANGLES, 0, mount.count)

            // 2) The module itself: lift to its mounting height, then tilt.
            //    Height and tilt live in the matrix, so the slider is free.
            val hh = p.heightM / 2f
            val lift = max(
                p.elevationM,
                hh * sin(Math.toRadians(p.tiltDeg.toDouble())).toFloat(),
            )
            System.arraycopy(modelMatrix, 0, scratchMatrix, 0, 16)
            Matrix.translateM(scratchMatrix, 0, 0f, lift, 0f)
            Matrix.rotateM(scratchMatrix, 0, p.tiltDeg, 1f, 0f, 0f)
            Matrix.multiplyMM(mvpMatrix, 0, vpMatrix, 0, scratchMatrix, 0)
            GLES20.glUniformMatrix4fv(mvpLoc, 1, false, mvpMatrix, 0)

            // 2a) Side walls.
            GLES20.glUniform4fv(colorLoc, 1, tint(SIDE_COLOR, alpha), 0)
            GLES20.glVertexAttribPointer(posLoc, 3, GLES20.GL_FLOAT, false, 0, module.side)
            GLES20.glVertexAttribPointer(uvLoc, 2, GLES20.GL_FLOAT, false, 0, zeroUVs)
            GLES20.glDrawArrays(GLES20.GL_TRIANGLES, 0, module.sideCount)

            // 2b) Textured photovoltaic glass top.
            GLES20.glUniform1i(useTexLoc, 1)
            GLES20.glVertexAttribPointer(posLoc, 3, GLES20.GL_FLOAT, false, 0, module.top)
            GLES20.glVertexAttribPointer(uvLoc, 2, GLES20.GL_FLOAT, false, 0, module.topUV)
            GLES20.glDrawArrays(GLES20.GL_TRIANGLES, 0, 6)

            // 2c) Trim ring — gold and doubled up when this panel is selected.
            GLES20.glUniform1i(useTexLoc, 0)
            GLES20.glUniform4fv(
                colorLoc, 1,
                tint(if (p.selected) SELECT_COLOR else FRAME_COLOR, alpha), 0,
            )
            GLES20.glVertexAttribPointer(posLoc, 3, GLES20.GL_FLOAT, false, 0, module.trim)
            GLES20.glVertexAttribPointer(uvLoc, 2, GLES20.GL_FLOAT, false, 0, zeroUVs)
            GLES20.glLineWidth(if (p.selected) 6f else 2f)
            GLES20.glDrawArrays(GLES20.GL_LINE_LOOP, 0, 4)
        }

        GLES20.glLineWidth(1f)
        GLES20.glDisableVertexAttribArray(posLoc)
        GLES20.glDisableVertexAttribArray(uvLoc)
        GLES20.glDisable(GLES20.GL_BLEND)
        GLES20.glDepthMask(true)
    }

    /** Translucent red rings showing where obstacles blocked placement. */
    private fun drawKeepOuts() {
        val pm = planeMatrix ?: return
        if (keepOuts.isEmpty()) return
        GLES20.glUseProgram(objProgram)
        GLES20.glEnable(GLES20.GL_BLEND)
        GLES20.glBlendFunc(GLES20.GL_SRC_ALPHA, GLES20.GL_ONE_MINUS_SRC_ALPHA)
        GLES20.glDepthMask(false)

        val mvpLoc    = GLES20.glGetUniformLocation(objProgram, "u_MVP")
        val colorLoc  = GLES20.glGetUniformLocation(objProgram, "u_Color")
        val posLoc    = GLES20.glGetAttribLocation(objProgram, "a_Position")
        val uvLoc     = GLES20.glGetAttribLocation(objProgram, "a_TexCoord")
        val useTexLoc = GLES20.glGetUniformLocation(objProgram, "u_useTexture")

        Matrix.multiplyMM(mvpMatrix, 0, vpMatrix, 0, pm, 0)
        GLES20.glUniformMatrix4fv(mvpLoc, 1, false, mvpMatrix, 0)
        GLES20.glUniform1i(useTexLoc, 0)
        GLES20.glUniform4fv(colorLoc, 1, KEEPOUT_COLOR, 0)
        GLES20.glEnableVertexAttribArray(posLoc)
        GLES20.glEnableVertexAttribArray(uvLoc)
        GLES20.glVertexAttribPointer(uvLoc, 2, GLES20.GL_FLOAT, false, 0, zeroUVs)
        GLES20.glLineWidth(4f)

        for (k in keepOuts) {
            ringBuf.clear()
            ringBuf.put(k.x - k.halfW).put(0.02f).put(k.z - k.halfD)
            ringBuf.put(k.x + k.halfW).put(0.02f).put(k.z - k.halfD)
            ringBuf.put(k.x + k.halfW).put(0.02f).put(k.z + k.halfD)
            ringBuf.put(k.x - k.halfW).put(0.02f).put(k.z + k.halfD)
            ringBuf.position(0)
            GLES20.glVertexAttribPointer(posLoc, 3, GLES20.GL_FLOAT, false, 0, ringBuf)
            GLES20.glDrawArrays(GLES20.GL_LINE_LOOP, 0, 4)
        }

        GLES20.glLineWidth(1f)
        GLES20.glDisableVertexAttribArray(posLoc)
        GLES20.glDisableVertexAttribArray(uvLoc)
        GLES20.glDisable(GLES20.GL_BLEND)
        GLES20.glDepthMask(true)
    }

    private val tinted = FloatArray(4)
    private fun tint(src: FloatArray, alpha: Float): FloatArray {
        tinted[0] = src[0]; tinted[1] = src[1]; tinted[2] = src[2]
        tinted[3] = src[3] * alpha
        return tinted
    }

    // ── Geometry ─────────────────────────────────────────────────────────────

    private fun mm(v: Float): Long = (v * 1000f).roundToInt().coerceIn(0, 65535).toLong()

    private fun moduleFor(w: Float, h: Float): ModuleGeom {
        val key = mm(w) or (mm(h) shl 16)
        return moduleCache.getOrPut(key) { buildModule(w, h) }
    }

    private fun mountFor(w: Float, h: Float, elevM: Float, tiltDeg: Float): MountGeom {
        // Elevation is quantised to 5 cm and tilt to whole degrees so dragging
        // the height slider reuses cached geometry instead of building a mesh
        // per millimetre.
        val eq = (elevM / 0.05f).roundToInt() * 0.05f
        val tq = tiltDeg.roundToInt().toFloat()
        val key = mm(w) or (mm(h) shl 16) or (mm(eq) shl 32) or
            (tq.toLong().coerceIn(0, 90) shl 48)
        if (mountCache.size > 96) mountCache.clear()
        return mountCache.getOrPut(key) { buildMount(w, h, eq, tq) }
    }

    private fun buildModule(w: Float, h: Float): ModuleGeom {
        val hw = w / 2f; val hh = h / 2f; val t = THICK
        val top = floatArrayOf(
            -hw, 0f, -hh,  hw, 0f, -hh,  hw, 0f, hh,
            -hw, 0f, -hh,  hw, 0f,  hh, -hw, 0f, hh,
        )
        val topUV = floatArrayOf(
            0f, 0f,  1f, 0f,  1f, 1f,
            0f, 0f,  1f, 1f,  0f, 1f,
        )
        // 4 walls as an explicit triangle list — no shared-offset fans, so a
        // draw can never read past the end of the buffer.
        val s = ArrayList<Float>(72)
        fun wall(ax: Float, az: Float, bx: Float, bz: Float) {
            s.add(ax); s.add(0f); s.add(az)
            s.add(bx); s.add(0f); s.add(bz)
            s.add(bx); s.add(-t); s.add(bz)
            s.add(ax); s.add(0f); s.add(az)
            s.add(bx); s.add(-t); s.add(bz)
            s.add(ax); s.add(-t); s.add(az)
        }
        wall(-hw, -hh,  hw, -hh)
        wall( hw, -hh,  hw,  hh)
        wall( hw,  hh, -hw,  hh)
        wall(-hw,  hh, -hw, -hh)

        val tw = 0.045f
        val trim = floatArrayOf(
            -hw - tw, 0.012f, -hh - tw,
             hw + tw, 0.012f, -hh - tw,
             hw + tw, 0.012f,  hh + tw,
            -hw - tw, 0.012f,  hh + tw,
        )
        return ModuleGeom(buf(top), buf(topUV), buf(s.toFloatArray()), s.size / 3, buf(trim))
    }

    /**
     * Mounting structure in the untilted anchor frame: roof plane at y = 0.
     *
     * Two rails run along the module's width under it, following the tilted
     * underside — so the rear rail sits higher than the front one. Four legs
     * drop from the rail ends to the roof, which is why a tilted array on a flat
     * roof has short front legs and tall rear legs.
     */
    private fun buildMount(w: Float, h: Float, elevM: Float, tiltDeg: Float): MountGeom {
        val hw = w / 2f; val hh = h / 2f
        val rad = Math.toRadians(tiltDeg.toDouble())
        val sinT = sin(rad).toFloat(); val cosT = cos(rad).toFloat()
        // A tilted module can never sink through the roof.
        val lift = max(elevM, hh * sinT)
        val o = ArrayList<Float>(6 * 36 * 3)
        val legX = hw * LEG_FRAC

        for (sign in intArrayOf(-1, 1)) {
            val p = sign * hh * RAIL_FRAC
            val railZ = p * cosT
            val railY = (lift + p * sinT - MOUNT_BAR * 2f).coerceAtLeast(MOUNT_BAR)
            box(o, 0f, railY, railZ, hw * 0.92f, MOUNT_BAR, MOUNT_BAR)
            val legH = railY / 2f
            if (legH > 0.005f) {
                box(o, -legX, legH, railZ, MOUNT_BAR, legH, MOUNT_BAR)
                box(o,  legX, legH, railZ, MOUNT_BAR, legH, MOUNT_BAR)
            }
        }
        return MountGeom(buf(o.toFloatArray()), o.size / 3)
    }

    /** Appends an axis-aligned box as 12 triangles (36 vertices). */
    private fun box(
        o: MutableList<Float>,
        cx: Float, cy: Float, cz: Float,
        hx: Float, hy: Float, hz: Float,
    ) {
        val x0 = cx - hx; val x1 = cx + hx
        val y0 = cy - hy; val y1 = cy + hy
        val z0 = cz - hz; val z1 = cz + hz
        fun v(x: Float, y: Float, z: Float) { o.add(x); o.add(y); o.add(z) }
        fun quad(
            ax: Float, ay: Float, az: Float, bx: Float, by: Float, bz: Float,
            cx2: Float, cy2: Float, cz2: Float, dx: Float, dy: Float, dz: Float,
        ) {
            v(ax, ay, az); v(bx, by, bz); v(cx2, cy2, cz2)
            v(ax, ay, az); v(cx2, cy2, cz2); v(dx, dy, dz)
        }
        quad(x0, y1, z0, x1, y1, z0, x1, y1, z1, x0, y1, z1) // top
        quad(x0, y0, z1, x1, y0, z1, x1, y0, z0, x0, y0, z0) // bottom
        quad(x0, y0, z0, x1, y0, z0, x1, y1, z0, x0, y1, z0) // front
        quad(x1, y0, z1, x0, y0, z1, x0, y1, z1, x1, y1, z1) // back
        quad(x0, y0, z1, x0, y0, z0, x0, y1, z0, x0, y1, z1) // left
        quad(x1, y0, z0, x1, y0, z1, x1, y1, z1, x1, y1, z0) // right
    }

    // ── Photovoltaic glass texture (procedural) ──────────────────────────────

    private fun buildSolarPanelTexture(): Int {
        val size = 256
        val bmp = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val c = Canvas(bmp)
        val px = size.toFloat()

        c.drawColor(0xFF14315A.toInt())

        val cols = 6; val rows = 4
        val cellW = px / cols; val cellH = px / rows
        val cellFill  = Paint().apply { color = 0xFF0E2B32.toInt() }
        val cellSheen = Paint().apply { color = 0xFF1D4E9E.toInt() }
        val busbar = Paint().apply { strokeWidth = px * 0.012f; color = 0xFFD8DEE6.toInt() }
        val edge = Paint().apply {
            style = Paint.Style.STROKE; strokeWidth = px * 0.008f; color = 0xFF6A87B0.toInt()
        }

        for (r in 0 until rows) {
            for (col in 0 until cols) {
                val l = col * cellW; val t = r * cellH
                val rect = RectF(l + 2f, t + 2f, l + cellW - 2f, t + cellH - 2f)
                c.drawRect(rect, cellFill)
                c.drawRect(rect, edge)
                c.drawRect(RectF(l + 2f, t + 2f, l + cellW - 2f, t + cellH * 0.45f), cellSheen)
                for (i in 0..3) {
                    val bx = l + cellW * (0.25f + 0.25f * i)
                    c.drawLine(bx, t + 3f, bx, t + cellH - 3f, busbar)
                }
            }
        }

        val fp = Paint().apply {
            style = Paint.Style.STROKE; strokeWidth = px * 0.035f; color = 0xFFB8C0C9.toInt()
        }
        c.drawRect(2f, 2f, px - 2f, px - 2f, fp)

        val tex = IntArray(1)
        GLES20.glGenTextures(1, tex, 0)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, tex[0])
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_REPEAT)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_REPEAT)
        GLUtils.texImage2D(GLES20.GL_TEXTURE_2D, 0, bmp, 0)
        bmp.recycle()
        return tex[0]
    }

    private fun buildProgram(vert: String, frag: String): Int {
        val vs = GLES20.glCreateShader(GLES20.GL_VERTEX_SHADER)
            .also { GLES20.glShaderSource(it, vert); GLES20.glCompileShader(it) }
        val fs = GLES20.glCreateShader(GLES20.GL_FRAGMENT_SHADER)
            .also { GLES20.glShaderSource(it, frag); GLES20.glCompileShader(it) }
        return GLES20.glCreateProgram().also {
            GLES20.glAttachShader(it, vs); GLES20.glAttachShader(it, fs); GLES20.glLinkProgram(it)
        }
    }

    private fun buf(arr: FloatArray): FloatBuffer =
        ByteBuffer.allocateDirect(arr.size * 4).order(ByteOrder.nativeOrder())
            .asFloatBuffer().apply { put(arr); position(0) }

    private val BG_VERT = """
        attribute vec4 a_Position;
        attribute vec2 a_TexCoord;
        varying vec2 v_TexCoord;
        void main() { gl_Position = a_Position; v_TexCoord = a_TexCoord; }
    """.trimIndent()

    private val BG_FRAG = """
        #extension GL_OES_EGL_image_external : require
        precision mediump float;
        uniform samplerExternalOES u_Texture;
        varying vec2 v_TexCoord;
        void main() { gl_FragColor = texture2D(u_Texture, v_TexCoord); }
    """.trimIndent()

    private val OBJ_VERT = """
        attribute vec4 a_Position;
        attribute vec2 a_TexCoord;
        uniform mat4 u_MVP;
        varying vec2 v_TexCoord;
        void main() { gl_Position = u_MVP * a_Position; v_TexCoord = a_TexCoord; }
    """.trimIndent()

    private val OBJ_FRAG = """
        precision mediump float;
        uniform vec4 u_Color;
        uniform int  u_useTexture;
        uniform sampler2D u_Texture;
        varying vec2 v_TexCoord;
        void main() {
            if (u_useTexture == 1) {
                gl_FragColor = texture2D(u_Texture, v_TexCoord);
            } else {
                gl_FragColor = u_Color;
            }
        }
    """.trimIndent()
}
