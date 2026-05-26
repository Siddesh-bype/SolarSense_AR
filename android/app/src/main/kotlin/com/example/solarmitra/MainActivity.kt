package com.example.solarmitra

import android.util.Log
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import android.content.Context
import android.Manifest
import androidx.activity.result.contract.ActivityResultContracts

class MainActivity : FlutterFragmentActivity() {

    companion object {
        private const val TAG       = "SolarMitra"
        private const val VIEW_TYPE = "com.solarmitra/scene"
        private const val METHOD_CH = "com.solarmitra/channel"
        private const val EVENT_CH  = "com.solarmitra/events"
    }

    // Register BEFORE Activity reaches STARTED state (AndroidX constraint).
    // Must be registered in the constructor / field-init phase, not lazily.
    private val cameraPermLauncher = registerForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted ->
        Log.e(TAG, "Camera permission result: granted=$granted")
        if (granted) {
            arManagerRef?.onCameraPermissionGranted()
        } else {
            // Surface the denial to Flutter so the AR screen can render a
            // fallback state instead of a frozen black camera view.
            // `shouldShowRequestPermissionRationale` returns FALSE when the
            // user selected "Don't ask again" (or the OS auto-denies), in
            // which case we direct them to app settings.
            val permanent = !shouldShowRequestPermissionRationale(
                android.Manifest.permission.CAMERA,
            )
            arManagerRef?.onCameraPermissionDenied(permanent)
        }
    }

    // Weak reference so ARSceneManager can receive the permission callback
    private var arManagerRef: ARSceneManager? = null

    private val arSceneManager: ARSceneManager by lazy {
        Log.e(TAG, "lazy ARSceneManager init")
        ARSceneManager(this, cameraPermLauncher).also { arManagerRef = it }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        Log.e(TAG, "configureFlutterEngine -- registering AR platform view")

        flutterEngine.platformViewsController.registry
            .registerViewFactory(
                VIEW_TYPE,
                object : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
                    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
                        Log.e(TAG, "factory.create() -- building ARSceneView")
                        return arSceneManager
                    }
                },
            )

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CH)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "addPanel"        -> { arSceneManager.addPanel();    result.success(null) }
                        "removePanel"     -> { arSceneManager.removePanel(); result.success(null) }
                        "resetScan"       -> { arSceneManager.resetScan();   result.success(null) }
                        "getScanSnapshot" -> result.success(arSceneManager.getScanSnapshot())
                        "configurePanelPose" -> {
                            val tilt       = (call.argument<Double>("tiltDeg")     ?: 20.0).toFloat()
                            val azimuth    = (call.argument<Double>("azimuthDeg")  ?: 180.0).toFloat()
                            val elevation  = (call.argument<Double>("elevationM")  ?: 0.75).toFloat()
                            arSceneManager.configurePanelPose(tilt, azimuth, elevation)
                            result.success(null)
                        }
                        "openAppSettings" -> {
                            val intent = android.content.Intent(
                                android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                android.net.Uri.fromParts("package", packageName, null),
                            ).apply {
                                addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            result.success(null)
                        }
                        else              -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("AR_ERROR", e.message, null)
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CH)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(args: Any?, sink: EventChannel.EventSink) {
                    Log.e(TAG, "EventChannel: HUD stream opened")
                    arSceneManager.eventSink = sink
                }
                override fun onCancel(args: Any?) {
                    arSceneManager.eventSink = null
                }
            })
    }
}
