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

    // Weak reference so ARSceneManager can receive the permission callback.
    // Re-assigned on every platform-view creation (see factory below).
    private var arManagerRef: ARSceneManager? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        Log.e(TAG, "configureFlutterEngine -- registering AR platform view")

        flutterEngine.platformViewsController.registry
            .registerViewFactory(
                VIEW_TYPE,
                object : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
                    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
                        Log.e(TAG, "factory.create() -- building ARSceneView #$viewId")
                        // A FRESH manager per view call. Reusing a singleton here
                        // leaves a closed session behind after dispose(), which
                        // produced a permanent black screen when the AR screen was
                        // reopened (sessionCreated stayed true, session == null).
                        return ARSceneManager(this@MainActivity, cameraPermLauncher).also {
                            arManagerRef = it
                        }
                    }
                },
            )

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CH)
            .setMethodCallHandler { call, result ->
                val mgr = arManagerRef
                try {
                    when (call.method) {
                        "checkArAvailability" -> {
                            val supported = try {
                                when (com.google.ar.core.ArCoreApk.getInstance()
                                    .checkAvailability(this)) {
                                    com.google.ar.core.ArCoreApk.Availability.SUPPORTED_INSTALLED,
                                    com.google.ar.core.ArCoreApk.Availability.SUPPORTED_APK_TOO_OLD,
                                    com.google.ar.core.ArCoreApk.Availability.SUPPORTED_NOT_INSTALLED,
                                    -> true
                                    else -> false
                                }
                            } catch (_: Exception) { false }
                            result.success(mapOf("supported" to supported))
                        }
                        "addPanel"        -> { mgr?.addPanel();    result.success(null) }
                        "removePanel"     -> { mgr?.removePanel(); result.success(null) }
                        "resetScan"       -> { mgr?.resetScan();   result.success(null) }
                        "getScanSnapshot" -> result.success(mgr?.getScanSnapshot() ?: emptyMap<String, Any>())
                        "captureFrame"    ->
                            if (mgr != null) mgr.requestCapture(result)
                            else result.error("AR_ERROR", "AR view not ready", null)
                        "configurePanelPose" -> {
                            val tilt       = (call.argument<Double>("tiltDeg")     ?: 20.0).toFloat()
                            val azimuth    = (call.argument<Double>("azimuthDeg")  ?: 180.0).toFloat()
                            val elevation  = (call.argument<Double>("elevationM")  ?: 0.75).toFloat()
                            mgr?.configurePanelPose(tilt, azimuth, elevation)
                            result.success(null)
                        }
                        "configurePanelFlex" -> {
                            val width   = (call.argument<Double>("widthM")  ?: 1.70).toFloat()
                            val height  = (call.argument<Double>("heightM") ?: 1.14).toFloat()
                            val layout  = call.argument<String>("layout")
                            mgr?.configurePanelFlex(width, height, layout)
                            result.success(null)
                        }
                        "setPanelHeight" -> {
                            val id        = call.argument<Int>("id") ?: -1
                            val elevation = (call.argument<Double>("elevationM") ?: 0.45).toFloat()
                            mgr?.setPanelHeight(id, elevation)
                            result.success(null)
                        }
                        "setAllPanelHeight" -> {
                            val elevation = (call.argument<Double>("elevationM") ?: 0.45).toFloat()
                            mgr?.setAllPanelHeight(elevation)
                            result.success(null)
                        }
                        "autoFillMixed" -> { mgr?.autoFillMixed(); result.success(null) }
                        "applyObstacles" -> {
                            @Suppress("UNCHECKED_CAST")
                            val boxes = call.argument<List<Map<String, Any>>>("boxes")
                                ?: emptyList()
                            mgr?.applyObstacles(boxes)
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
                    arManagerRef?.eventSink = sink
                }
                override fun onCancel(args: Any?) {
                    arManagerRef?.eventSink = null
                }
            })
    }
}
