package com.example.solarsense_ar

import android.util.Log
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import android.content.Context

/**
 * FlutterFragmentActivity is the correct base class when ARSceneView 2.2.1 is involved.
 * It extends AppCompatActivity → FragmentActivity → ComponentActivity, so
 * passing `this` to ARSceneManager(activity: ComponentActivity) is type-safe with NO cast.
 *
 * NOTE: FlutterActivity extends Activity directly (not ComponentActivity), which is
 * why ARSceneView 2.2.1 crashes with ClassCastException when FlutterActivity is used.
 */
class MainActivity : FlutterFragmentActivity() {

    companion object {
        private const val TAG       = "SolarSenseAR"
        private const val VIEW_TYPE = "com.solarsense.ar/scene"
        private const val METHOD_CH = "com.solarsense.ar/channel"
        private const val EVENT_CH  = "com.solarsense.ar/events"
    }

    // FlutterFragmentActivity IS-A ComponentActivity — no cast required
    private val arSceneManager by lazy {
        Log.d(TAG, "▶ lazy ARSceneManager init")
        ARSceneManager(this)   // 'this' is ComponentActivity via FlutterFragmentActivity
    }

    /**
     * FlutterFragmentActivity delegates engine creation differently from FlutterActivity.
     * Override provideFlutterEngine to cache the engine, which guarantees this class
     * participates in configureFlutterEngine.
     *
     * Simply calling super.configureFlutterEngine works — the key is that
     * FlutterFragmentActivity's internal FlutterFragment also forwards this call.
     */
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        Log.d(TAG, "✔ configureFlutterEngine — registering AR platform view")

        // ── Platform view ─────────────────────────────────────────────────────
        flutterEngine.platformViewsController.registry
            .registerViewFactory(
                VIEW_TYPE,
                object : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
                    override fun create(
                        context: Context, viewId: Int, args: Any?,
                    ): PlatformView {
                        Log.d(TAG, "▶ factory.create() — building ARSceneView")
                        return arSceneManager
                    }
                },
            )

        // ── MethodChannel ─────────────────────────────────────────────────────
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

        // ── EventChannel ──────────────────────────────────────────────────────
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CH)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(args: Any?, sink: EventChannel.EventSink) {
                    Log.d(TAG, "EventChannel: HUD stream opened")
                    arSceneManager.eventSink = sink
                }
                override fun onCancel(args: Any?) {
                    arSceneManager.eventSink = null
                }
            })
    }
}
