package com.example.solarsense_ar

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import android.content.Context
import kotlinx.coroutines.MainScope
import kotlinx.coroutines.cancel

class MainActivity : FlutterFragmentActivity() {

    companion object {
        private const val VIEW_TYPE = "com.solarsense.ar/scene"
        private const val METHOD_CH = "com.solarsense.ar/channel"
        private const val EVENT_CH  = "com.solarsense.ar/events"
    }

    private val scope = MainScope()
    // ARSceneManager needs 'this' as ComponentActivity but FlutterActivity IS an AppCompatActivity
    // so the lazy init correctly defers until configureFlutterEngine (post-onCreate).
    private val arSceneManager by lazy { ARSceneManager(this) }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── 1. Platform view ─────────────────────────────────────────────────
        flutterEngine.platformViewsController.registry
            .registerViewFactory(
                VIEW_TYPE,
                object : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
                    override fun create(
                        context: Context, viewId: Int, args: Any?,
                    ): PlatformView = arSceneManager
                },
            )

        // ── 2. MethodChannel ─────────────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CH)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "addPanel"        -> { arSceneManager.addPanel();    result.success(null) }
                        "removePanel"     -> { arSceneManager.removePanel(); result.success(null) }
                        "resetScan"       -> { arSceneManager.resetScan();   result.success(null) }
                        "getScanSnapshot" -> result.success(arSceneManager.getScanSnapshot())
                        else              -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("AR_ERROR", e.message, null)
                }
            }

        // ── 3. EventChannel ──────────────────────────────────────────────────
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CH)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(args: Any?, sink: EventChannel.EventSink) {
                    arSceneManager.eventSink = sink
                }
                override fun onCancel(args: Any?) {
                    arSceneManager.eventSink = null
                }
            })
    }

    // ARSceneView 2.2.1 manages its own lifecycle via the Activity reference.
    // We don't call resume()/pause() manually — the Lifecycle observer handles it.

    override fun onDestroy() {
        super.onDestroy()
        scope.cancel()
    }
}
