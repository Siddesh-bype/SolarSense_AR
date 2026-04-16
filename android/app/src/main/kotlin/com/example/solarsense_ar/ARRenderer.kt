package com.example.solarsense_ar

import android.content.Context
import android.opengl.GLES20
import android.opengl.Matrix
import android.util.Log
import android.view.Surface
import com.google.ar.core.Anchor
import com.google.ar.core.Frame
import com.google.ar.core.Session
import com.google.ar.core.TrackingState
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer
import javax.microedition.khronos.egl.EGLConfig
import javax.microedition.khronos.opengles.GL10

class ARRenderer(
    private val context: Context,
    private val onFrameCallback: (Frame) -> Unit,
) : android.opengl.GLSurfaceView.Renderer {

    companion object {
        private const val TAG = "SolarSenseAR"
        private val PANEL_COLOR = floatArrayOf(0.09f, 0.18f, 0.42f, 0.88f)
        private val FRAME_COLOR = floatArrayOf(0.80f, 0.80f, 0.80f, 1.00f)
        private val GRID_COLOR  = floatArrayOf(0.20f, 0.60f, 1.00f, 0.35f)
        private const val PANEL_W = 1.70f
        private const val PANEL_H = 1.14f
    }

    // Called on UI thread when GL surface + texture are ready for session setup
    var onSurfaceReadyCallback: (() -> Unit)? = null

    private var session: Session? = null
    private val cameraTexId = IntArray(1)
    private val anchors = mutableListOf<Anchor>()

    private var viewportWidth = 0
    private var viewportHeight = 0

    private var bgProgram  = 0
    private var objProgram = 0

    private val projMatrix = FloatArray(16)
    private val viewMatrix = FloatArray(16)

    // Panel geometry: flat rectangle at y=0, centred at origin
    private val panelVerts: FloatBuffer = run {
        val hw = PANEL_W / 2f; val hh = PANEL_H / 2f
        val v = floatArrayOf(-hw,0f,-hh, hw,0f,-hh, hw,0f,hh, -hw,0f,hh)
        ByteBuffer.allocateDirect(v.size * 4).order(ByteOrder.nativeOrder())
            .asFloatBuffer().apply { put(v); position(0) }
    }

    // Full-screen quad
    private val quadCoords = floatArrayOf(-1f,-1f, 1f,-1f, -1f,1f, 1f,1f)
    private val quadUVs    = floatArrayOf( 0f, 1f, 1f, 1f,  0f,0f, 1f,0f)
    private lateinit var quadCoordsBuffer: FloatBuffer
    private lateinit var quadUVsBuffer: FloatBuffer

    // ── Session integration ───────────────────────────────────────────────────

    /** Called from UI thread; queues onto GL thread internally via glSurfaceView.queueEvent. */
    fun initCameraTexture(s: Session) {
        val OES = 0x8D65
        GLES20.glGenTextures(1, cameraTexId, 0)
        GLES20.glBindTexture(OES, cameraTexId[0])
        GLES20.glTexParameteri(OES, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE)
        GLES20.glTexParameteri(OES, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE)
        GLES20.glTexParameteri(OES, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_NEAREST)
        GLES20.glTexParameteri(OES, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_NEAREST)
        s.setCameraTextureName(cameraTexId[0])
        
        // Critical: Apply viewport geometry because SurfaceChanged happens BEFORE session is created
        if (viewportWidth > 0 && viewportHeight > 0) {
            s.setDisplayGeometry(Surface.ROTATION_0, viewportWidth, viewportHeight) // 0 = portrait
            Log.e(TAG, "Applied session geometry inside initCameraTexture: ${viewportWidth}x${viewportHeight}")
        }
        
        session = s
        Log.e(TAG, "Camera texture bound: texId=${cameraTexId[0]}")
    }

    @Synchronized fun addAnchor(a: Anchor)      { anchors += a }
    @Synchronized fun removeLastAnchor()         { if (anchors.isNotEmpty()) { anchors.last().detach(); anchors.removeLast() } }
    @Synchronized fun clearAnchors()             { anchors.forEach { it.detach() }; anchors.clear() }

    // ── GLSurfaceView.Renderer ────────────────────────────────────────────────

    override fun onSurfaceCreated(gl: GL10?, config: EGLConfig?) {
        Log.e(TAG, "GL surface created")
        GLES20.glClearColor(0f, 0f, 0f, 1f)

        bgProgram  = buildProgram(BG_VERT,  BG_FRAG)
        objProgram = buildProgram(OBJ_VERT, OBJ_FRAG)

        quadCoordsBuffer = buf(quadCoords)
        quadUVsBuffer    = buf(quadUVs)

        // Notify that surface is ready — session can now be created
        onSurfaceReadyCallback?.invoke()
    }

    override fun onSurfaceChanged(gl: GL10?, w: Int, h: Int) {
        viewportWidth = w
        viewportHeight = h
        GLES20.glViewport(0, 0, w, h)
        session?.setDisplayGeometry(Surface.ROTATION_0, w, h) // Update if already exists
        Log.e(TAG, "onSurfaceChanged: ${w}x${h}")
    }

    override fun onDrawFrame(gl: GL10?) {
        GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT or GLES20.GL_DEPTH_BUFFER_BIT)
        val s = session ?: return

        val frame = try { s.update() } catch (e: Exception) {
            Log.e(TAG, "session.update: ${e.message}")
            return
        }

        drawBackground()

        frame.camera.getProjectionMatrix(projMatrix, 0, 0.1f, 100f)
        frame.camera.getViewMatrix(viewMatrix, 0)

        onFrameCallback(frame)

        if (frame.camera.trackingState == TrackingState.TRACKING) {
            synchronized(this) { drawPanels() }
        }
    }

    // ── Draw calls ────────────────────────────────────────────────────────────

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

        val vp = FloatArray(16).also { Matrix.multiplyMM(it, 0, projMatrix, 0, viewMatrix, 0) }
        val mvpLoc   = GLES20.glGetUniformLocation(objProgram, "u_MVP")
        val colorLoc = GLES20.glGetUniformLocation(objProgram, "u_Color")
        val posLoc   = GLES20.glGetAttribLocation(objProgram, "a_Position")

        GLES20.glEnableVertexAttribArray(posLoc)
        GLES20.glVertexAttribPointer(posLoc, 3, GLES20.GL_FLOAT, false, 0, panelVerts)

        for (anchor in anchors) {
            if (anchor.trackingState != TrackingState.TRACKING) continue
            val model = FloatArray(16).also { anchor.pose.toMatrix(it, 0) }
            val mvp   = FloatArray(16).also { Matrix.multiplyMM(it, 0, vp, 0, model, 0) }
            GLES20.glUniformMatrix4fv(mvpLoc, 1, false, mvp, 0)

            // Solid fill
            GLES20.glUniform4fv(colorLoc, 1, PANEL_COLOR, 0)
            GLES20.glDrawArrays(GLES20.GL_TRIANGLE_FAN, 0, 4)

            // Outline
            GLES20.glUniform4fv(colorLoc, 1, FRAME_COLOR, 0)
            GLES20.glDrawArrays(GLES20.GL_LINE_LOOP, 0, 4)
        }

        GLES20.glDisableVertexAttribArray(posLoc)
        GLES20.glDisable(GLES20.GL_BLEND)
    }

    // ── Shader helpers ────────────────────────────────────────────────────────

    private fun buildProgram(vert: String, frag: String): Int {
        val vs = GLES20.glCreateShader(GLES20.GL_VERTEX_SHADER).also   { GLES20.glShaderSource(it, vert); GLES20.glCompileShader(it) }
        val fs = GLES20.glCreateShader(GLES20.GL_FRAGMENT_SHADER).also { GLES20.glShaderSource(it, frag); GLES20.glCompileShader(it) }
        return GLES20.glCreateProgram().also { GLES20.glAttachShader(it, vs); GLES20.glAttachShader(it, fs); GLES20.glLinkProgram(it) }
    }

    private fun buf(arr: FloatArray): FloatBuffer =
        ByteBuffer.allocateDirect(arr.size * 4).order(ByteOrder.nativeOrder())
            .asFloatBuffer().apply { put(arr); position(0) }

    // ── GLSL sources ──────────────────────────────────────────────────────────

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
