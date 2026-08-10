package com.example.solarmitra

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.opengl.GLES20
import android.opengl.GLUtils
import android.opengl.Matrix
import android.util.Log
import android.view.Surface
import com.google.ar.core.Anchor
import com.google.ar.core.Coordinates2d
import com.google.ar.core.Frame
import com.google.ar.core.Session
import com.google.ar.core.TrackingState
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer
import javax.microedition.khronos.egl.EGLConfig
import javax.microedition.khronos.opengles.GL10

/**
 * Raw OpenGL ES 2.0 renderer for the ARCore camera feed + 3D solar panels.
 *
 * Panels are drawn as extruded 3D modules: a silver aluminium bezel, a
 * textured photovoltaic glass top (procedurally generated blue cell grid with
 * busbars), 4 side walls and a thin outer frame. Panel width/height are
 * configurable so the Dart side can present different panel sizes the user can
 * switch between. All geometry is transformed by the ARCore anchor pose, so
 * tilt/azimuth/elevation from Dart all apply.
 */
class ARRenderer(
    private val context: Context,
    private val onFrameCallback: (Frame) -> Unit,
    private val rotationSupplier: () -> Int = { Surface.ROTATION_0 },
) : android.opengl.GLSurfaceView.Renderer {

    companion object {
        private const val TAG = "SolarMitra"
        private val SIDE_COLOR  = floatArrayOf(0.05f, 0.10f, 0.24f, 1.00f)
        private val FRAME_COLOR = floatArrayOf(0.72f, 0.75f, 0.79f, 1.00f)
        private const val THICK   = 0.06f // panel box thickness (m)

        // Default PV module (540 Wp mono-PERC, landscape).
        private const val DEFAULT_W = 1.70f
        private const val DEFAULT_H = 1.14f
    }

    var onSurfaceReadyCallback: (() -> Unit)? = null

    private var session: Session? = null
    private val cameraTexId = IntArray(1)
    private var panelTexId = 0
    private val anchors = mutableListOf<Anchor>()
    private val panelAlphas = mutableListOf<Float>()

    private var viewportWidth = 0
    private var viewportHeight = 0
    @Volatile private var pendingRotationUpdate = false

    private var bgProgram  = 0
    private var objProgram = 0

    private val projMatrix = FloatArray(16)
    private val viewMatrix = FloatArray(16)

    // Panel module dimensions (m).
    @Volatile private var panelW = DEFAULT_W
    @Volatile private var panelH = DEFAULT_H
    @Volatile private var geometryDirty = true

    // Rebuilt geometry (top face, 4 walls, 2 UV triangles, breaker ring).
    private var topVerts: FloatBuffer = ByteBuffer.allocateDirect(0).asFloatBuffer()
    private var sideVerts: FloatBuffer = ByteBuffer.allocateDirect(0).asFloatBuffer()
    private var topUVs: FloatBuffer = ByteBuffer.allocateDirect(0).asFloatBuffer()
    private var trimVerts: FloatBuffer = ByteBuffer.allocateDirect(0).asFloatBuffer()

    // Camera background quad.
    private val quadCoords = floatArrayOf(-1f,-1f, 1f,-1f, -1f,1f, 1f,1f)
    private val quadUVs    = floatArrayOf( 0f, 1f, 1f, 1f,  0f,0f, 1f,0f)
    private lateinit var quadCoordsBuffer: FloatBuffer
    private lateinit var quadUVsBuffer: FloatBuffer

    fun setPanelSize(widthM: Float, heightM: Float) {
        val w = widthM.coerceIn(0.8f, 3.0f)
        val h = heightM.coerceIn(0.5f, 2.2f)
        if (w != panelW || h != panelH) {
            panelW = w; panelH = h
            geometryDirty = true
        }
    }

    private fun rebuildGeometry() {
        val hw = panelW / 2f; val hh = panelH / 2f; val t = THICK
        // Top face — split into two triangles (clockwise winding, CCW normal +Y)
        topVerts = buf(floatArrayOf(
            -hw,0f,-hh,  hw,0f,-hh,  hw,0f,hh,
            -hw,0f,-hh,  hw,0f,hh,  -hw,0f,hh,
        ))
        topUVs = buf(floatArrayOf(
            0f,0f,  1f,0f,  1f,1f,
            0f,0f,  1f,1f,  0f,1f,
        ))
        // Side walls (top edge → bottom edge at y=-t)
        sideVerts = buf(floatArrayOf(
            // front (z=-hh)
            -hw,0f,-hh,  hw,0f,-hh,  hw,-t,-hh,  -hw,-t,-hh,
            // right (x=hw)
             hw,0f,-hh,  hw,0f, hh,  hw,-t, hh,  hw,-t,-hh,
            // back (z=hh)
             hw,0f, hh, -hw,0f, hh, -hw,-t, hh,  hw,-t, hh,
            // left (x=-hw)
            -hw,0f, hh, -hw,0f,-hh, -hw,-t,-hh, -hw,-t, hh,
        ))
        // Outer aluminium trim — a raised bevelled ring (4 line segments).
        val tw = 0.045f
        trimVerts = buf(floatArrayOf(
            -hw-tw, 0.012f, -hh-tw,  hw+tw, 0.012f, -hh-tw,
             hw+tw, 0.012f, -hh-tw,  hw+tw, 0.012f,  hh+tw,
             hw+tw, 0.012f,  hh+tw, -hw-tw, 0.012f,  hh+tw,
            -hw-tw, 0.012f,  hh+tw, -hw-tw, 0.012f, -hh-tw,
        ))
        geometryDirty = false
    }

    fun initCameraTexture(s: Session) {
        val OES = 0x8D65
        GLES20.glGenTextures(1, cameraTexId, 0)
        GLES20.glBindTexture(OES, cameraTexId[0])
        GLES20.glTexParameteri(OES, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE)
        GLES20.glTexParameteri(OES, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE)
        GLES20.glTexParameteri(OES, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_NEAREST)
        GLES20.glTexParameteri(OES, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_NEAREST)
        s.setCameraTextureName(cameraTexId[0])
        if (viewportWidth > 0 && viewportHeight > 0) {
            val rot = rotationSupplier()
            s.setDisplayGeometry(rot, viewportWidth, viewportHeight)
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

    @Synchronized fun addAnchor(a: Anchor)      { anchors += a; panelAlphas += 1.0f }
    @Synchronized fun removeLastAnchor() {
        if (anchors.isNotEmpty()) { anchors.last().detach(); anchors.removeLast(); panelAlphas.removeLast() }
    }
    @Synchronized fun clearAnchors() { anchors.forEach { it.detach() }; anchors.clear(); panelAlphas.clear() }

    /** Sets the occlusion dim factor (0.0–1.0) for a panel by index. */
    @Synchronized fun setOcclusion(index: Int, alpha: Float) {
        if (index in panelAlphas.indices) panelAlphas[index] = alpha
    }

    override fun onSurfaceCreated(gl: GL10?, config: EGLConfig?) {
        GLES20.glClearColor(0f, 0f, 0f, 1f)
        bgProgram  = buildProgram(BG_VERT,  BG_FRAG)
        objProgram = buildProgram(OBJ_VERT, OBJ_FRAG)
        quadCoordsBuffer = buf(quadCoords)
        quadUVsBuffer    = buf(quadUVs)
        panelTexId = buildSolarPanelTexture()
        geometryDirty = true
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
        val frame = try { s.update() } catch (e: Exception) { return }
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
        onFrameCallback(frame)
        if (frame.camera.trackingState == TrackingState.TRACKING) {
            synchronized(this) { if (geometryDirty) rebuildGeometry(); drawPanels() }
        }
    }

    private fun drawBackground() {
        GLES20.glDisable(GLES20.GL_DEPTH_TEST)
        GLES20.glDepthMask(false)
        GLES20.glUseProgram(bgProgram)
        val posLoc = GLES20.glGetAttribLocation(bgProgram, "a_Position")
        val uvLoc  = GLES20.glGetAttribLocation(bgProgram, "a_TexCoord")
        val texLoc = GLES20.glGetUniformLocation(bgProgram, "u_Texture")
        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(0x8D65, cameraTexId[0])
        GLES20.glUniform1i(texLoc, 0)
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
        if (anchors.isEmpty()) return
        GLES20.glUseProgram(objProgram)
        GLES20.glEnable(GLES20.GL_BLEND)
        GLES20.glBlendFunc(GLES20.GL_SRC_ALPHA, GLES20.GL_ONE_MINUS_SRC_ALPHA)
        GLES20.glEnable(GLES20.GL_DEPTH_TEST)
        GLES20.glDepthMask(false) // panels blend against the camera feed

        val vp = FloatArray(16).also { Matrix.multiplyMM(it, 0, projMatrix, 0, viewMatrix, 0) }
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

        for ((i, anchor) in anchors.withIndex()) {
            if (anchor.trackingState != TrackingState.TRACKING) continue
            val alpha = panelAlphas.getOrElse(i) { 1.0f }
            val model = FloatArray(16).also { anchor.pose.toMatrix(it, 0) }
            val mvp   = FloatArray(16).also { Matrix.multiplyMM(it, 0, vp, 0, model, 0) }
            GLES20.glUniformMatrix4fv(mvpLoc, 1, false, mvp, 0)

            // 1) Solid side walls (darker underside)
            GLES20.glUniform1i(useTexLoc, 0)
            GLES20.glVertexAttribPointer(posLoc, 3, GLES20.GL_FLOAT, false, 0, sideVerts)
            GLES20.glVertexAttribPointer(uvLoc, 2, GLES20.GL_FLOAT, false, 0, topUVs)
            GLES20.glUniform4fv(colorLoc, 1, tint(SIDE_COLOR, alpha), 0)
            GLES20.glDrawArrays(GLES20.GL_TRIANGLE_FAN, 0, 4)
            GLES20.glDrawArrays(GLES20.GL_TRIANGLE_FAN, 4, 4)
            GLES20.glDrawArrays(GLES20.GL_TRIANGLE_FAN, 8, 4)
            GLES20.glDrawArrays(GLES20.GL_TRIANGLE_FAN, 12, 4)

            // 2) Textured photovoltaic glass top
            GLES20.glUniform1i(useTexLoc, 1)
            GLES20.glVertexAttribPointer(posLoc, 3, GLES20.GL_FLOAT, false, 0, topVerts)
            GLES20.glVertexAttribPointer(uvLoc, 2, GLES20.GL_FLOAT, false, 0, topUVs)
            GLES20.glDrawArrays(GLES20.GL_TRIANGLES, 0, 6)

            // 3) Aluminium trim ring (raised bevelled edge)
            GLES20.glUniform1i(useTexLoc, 0)
            GLES20.glUniform4fv(colorLoc, 1, tint(FRAME_COLOR, alpha), 0)
            GLES20.glVertexAttribPointer(posLoc, 3, GLES20.GL_FLOAT, false, 0, trimVerts)
            GLES20.glDrawArrays(GLES20.GL_LINE_LOOP, 0, trimVerts.capacity() / 3)
        }

        GLES20.glDisableVertexAttribArray(posLoc)
        GLES20.glDisableVertexAttribArray(uvLoc)
        GLES20.glDisable(GLES20.GL_BLEND)
        GLES20.glDepthMask(true)
    }

    // Tint helper: scale rgb by alpha, keep/compute a (alpha).
    private val _tinted = FloatArray(4)
    private fun tint(src: FloatArray, alpha: Float): FloatArray {
        _tinted[0] = src[0]; _tinted[1] = src[1]; _tinted[2] = src[2]; _tinted[3] = src[3] * alpha
        return _tinted
    }

    // ── Photovoltaic glass texture (procedural) ─────────────────────────────
    private fun buildSolarPanelTexture(): Int {
        val size = 256
        val bmp = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val c = Canvas(bmp)
        val px = size.toFloat()

        // Base glass — deep blue.
        c.drawColor(0xFF14315A.toInt())

        // Row of photovoltaic cells (6 × 4) with dark blue fill and silver edges.
        val cols = 6; val rows = 4
        val cellW = px / cols; val cellH = px / rows
        val cellFill = Paint().apply { color = 0xFF0E2B32.toInt() }
        val cellSheen = Paint().apply { color = 0xFF1D4E9E.toInt() }
        val busbar = Paint().apply { strokeWidth = px * 0.012f; color = 0xFFD8DEE6.toInt() }
        val edge = Paint().apply { style = Paint.Style.STROKE; strokeWidth = px * 0.008f; color = 0xFF6A87B0.toInt() }

        for (r in 0 until rows) {
            for (col in 0 until cols) {
                val l = col * cellW; val t = r * cellH
                val rect = RectF(l + 2f, t + 2f, l + cellW - 2f, t + cellH - 2f)
                c.drawRect(rect, cellFill)
                c.drawRect(rect, edge)
                // Diagonal glass sheen so the module reads as reflective glass.
                c.drawRect(
                    RectF(l + 2f, t + 2f, l + cellW - 2f, t + cellH * 0.45f),
                    cellSheen,
                )
                // Vertical busbars down each cell.
                for (i in 0..3) {
                    val bx = l + cellW * (0.25f + 0.25f * i)
                    c.drawLine(bx, t + 3f, bx, t + cellH - 3f, busbar)
                }
            }
        }

        // Aluminium frame around the module.
        val fp = Paint().apply { style = Paint.Style.STROKE; strokeWidth = px * 0.035f; color = 0xFFB8C0C9.toInt() }
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
        val vs = GLES20.glCreateShader(GLES20.GL_VERTEX_SHADER).also   { GLES20.glShaderSource(it, vert); GLES20.glCompileShader(it) }
        val fs = GLES20.glCreateShader(GLES20.GL_FRAGMENT_SHADER).also { GLES20.glShaderSource(it, frag); GLES20.glCompileShader(it) }
        return GLES20.glCreateProgram().also { GLES20.glAttachShader(it, vs); GLES20.glAttachShader(it, fs); GLES20.glLinkProgram(it) }
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