package com.example.solarmitra

import android.content.Context
import android.opengl.GLES20
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
 * Panels are now drawn as extruded 3D boxes (top face + 4 side walls) with a
 * cell grid on the top surface, instead of the previous flat coloured quad —
 * so they read as real raised modules under the camera. Each panel carries an
 * occlusion alpha (default 1.0) that the scene manager can dim when a panel is
 * behind real-world geometry (depth occlusion). All geometry is transformed by
 * the ARCore anchor pose, so tilt/azimuth/elevation from Dart all apply.
 */
class ARRenderer(
    private val context: Context,
    private val onFrameCallback: (Frame) -> Unit,
    private val rotationSupplier: () -> Int = { Surface.ROTATION_0 },
) : android.opengl.GLSurfaceView.Renderer {

    companion object {
        private const val TAG = "SolarMitra"
        private val PANEL_COLOR = floatArrayOf(0.09f, 0.18f, 0.42f, 1.00f)
        private val SIDE_COLOR  = floatArrayOf(0.05f, 0.10f, 0.24f, 1.00f)
        private val FRAME_COLOR = floatArrayOf(0.85f, 0.85f, 0.85f, 1.00f)
        private val CELL_COLOR  = floatArrayOf(0.35f, 0.45f, 0.70f, 0.55f)
        private const val PANEL_W = 1.70f
        private const val PANEL_H = 1.14f
        private const val THICK   = 0.06f // panel box thickness (m)
    }

    var onSurfaceReadyCallback: (() -> Unit)? = null

    private var session: Session? = null
    private val cameraTexId = IntArray(1)
    private val anchors = mutableListOf<Anchor>()
    private val panelAlphas = mutableListOf<Float>()

    private var viewportWidth = 0
    private var viewportHeight = 0
    @Volatile private var pendingRotationUpdate = false

    private var bgProgram  = 0
    private var objProgram = 0

    private val projMatrix = FloatArray(16)
    private val viewMatrix = FloatArray(16)

    // Top face (flat rect) — used for both fill and cell grid.
    private val topVerts: FloatBuffer
    // 4 side walls, each a quad, as TRIANGLE_FAN (4 verts × 4 walls).
    private val sideVerts: FloatBuffer

    private val quadCoords = floatArrayOf(-1f,-1f, 1f,-1f, -1f,1f, 1f,1f)
    private val quadUVs    = floatArrayOf( 0f, 1f, 1f, 1f,  0f,0f, 1f,0f)
    private lateinit var quadCoordsBuffer: FloatBuffer
    private lateinit var quadUVsBuffer: FloatBuffer

    // Cell grid lines on the top face (6 columns × 4 rows).
    private val cellLines: FloatBuffer

    init {
        val hw = PANEL_W / 2f; val hh = PANEL_H / 2f; val t = THICK
        // Top face
        val top = floatArrayOf(-hw,0f,-hh, hw,0f,-hh, hw,0f,hh, -hw,0f,hh)
        topVerts = buf(top)
        // Side walls (top edge → bottom edge at y=-t)
        val sides = floatArrayOf(
            // front (z=-hh)
            -hw,0f,-hh,  hw,0f,-hh,  hw,-t,-hh,  -hw,-t,-hh,
            // right (x=hw)
             hw,0f,-hh,  hw,0f, hh,  hw,-t, hh,  hw,-t,-hh,
            // back (z=hh)
             hw,0f, hh, -hw,0f, hh, -hw,-t, hh,  hw,-t, hh,
            // left (x=-hw)
            -hw,0f, hh, -hw,0f,-hh, -hw,-t,-hh, -hw,-t, hh,
        )
        sideVerts = buf(sides)
        // Cell grid
        val cells = mutableListOf<Float>()
        val cols = 6; val rows = 4
        for (i in 0..cols) {
            val x = -hw + (PANEL_W * i / cols)
            cells += x; 0f; -hh;  x; 0f; hh
        }
        for (j in 0..rows) {
            val z = -hh + (PANEL_H * j / rows)
            cells += -hw; 0f; z;  hw; 0f; z
        }
        cellLines = buf(cells.toFloatArray())
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
            synchronized(this) { drawPanels() }
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

        val vp = FloatArray(16).also { Matrix.multiplyMM(it, 0, projMatrix, 0, viewMatrix, 0) }
        val mvpLoc   = GLES20.glGetUniformLocation(objProgram, "u_MVP")
        val colorLoc = GLES20.glGetUniformLocation(objProgram, "u_Color")
        val posLoc   = GLES20.glGetAttribLocation(objProgram, "a_Position")

        GLES20.glEnableVertexAttribArray(posLoc)

        for ((i, anchor) in anchors.withIndex()) {
            if (anchor.trackingState != TrackingState.TRACKING) continue
            val alpha = panelAlphas.getOrElse(i) { 1.0f }
            val model = FloatArray(16).also { anchor.pose.toMatrix(it, 0) }
            val mvp   = FloatArray(16).also { Matrix.multiplyMM(it, 0, vp, 0, model, 0) }
            GLES20.glUniformMatrix4fv(mvpLoc, 1, false, mvp, 0)

            // Side walls (darker)
            GLES20.glVertexAttribPointer(posLoc, 3, GLES20.GL_FLOAT, false, 0, sideVerts)
            GLES20.glUniform4fv(colorLoc, 1, tint(SIDE_COLOR, alpha), 0)
            GLES20.glDrawArrays(GLES20.GL_TRIANGLE_FAN, 0, 4)
            GLES20.glDrawArrays(GLES20.GL_TRIANGLE_FAN, 4, 4)
            GLES20.glDrawArrays(GLES20.GL_TRIANGLE_FAN, 8, 4)
            GLES20.glDrawArrays(GLES20.GL_TRIANGLE_FAN, 12, 4)

            // Top face (panel colour)
            GLES20.glVertexAttribPointer(posLoc, 3, GLES20.GL_FLOAT, false, 0, topVerts)
            GLES20.glUniform4fv(colorLoc, 1, tint(PANEL_COLOR, alpha), 0)
            GLES20.glDrawArrays(GLES20.GL_TRIANGLE_FAN, 0, 4)

            // Cell grid on top
            GLES20.glUniform4fv(colorLoc, 1, tint(CELL_COLOR, alpha), 0)
            GLES20.glVertexAttribPointer(posLoc, 3, GLES20.GL_FLOAT, false, 0, cellLines)
            GLES20.glDrawArrays(GLES20.GL_LINES, 0, cellLines.capacity() / 3)

            // Outline
            GLES20.glUniform4fv(colorLoc, 1, tint(FRAME_COLOR, alpha), 0)
            GLES20.glVertexAttribPointer(posLoc, 3, GLES20.GL_FLOAT, false, 0, topVerts)
            GLES20.glDrawArrays(GLES20.GL_LINE_LOOP, 0, 4)
        }

        GLES20.glDisableVertexAttribArray(posLoc)
        GLES20.glDisable(GLES20.GL_BLEND)
    }

    // Tint helper: scale rgb by alpha, keep/compute a (alpha).
    private val _tinted = FloatArray(4)
    private fun tint(src: FloatArray, alpha: Float): FloatArray {
        _tinted[0] = src[0]; _tinted[1] = src[1]; _tinted[2] = src[2]; _tinted[3] = src[3] * alpha
        return _tinted
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
        uniform mat4 u_MVP;
        void main() { gl_Position = u_MVP * a_Position; }
    """.trimIndent()

    private val OBJ_FRAG = """
        precision mediump float;
        uniform vec4 u_Color;
        void main() { gl_FragColor = u_Color; }
    """.trimIndent()
}
