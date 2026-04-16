package com.example.solarsense_ar

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val AR_VIEW_TYPE = "com.solarsense.ar/arview"
        private const val CHANNEL      = "com.solarsense.ar/control"
    }

    private val arFactory = ARSceneViewFactory()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Register the AR platform view
        flutterEngine
            .platformViewsController
            .registry
            .registerViewFactory(AR_VIEW_TYPE, arFactory)

        // MethodChannel for Flutter → Kotlin control messages
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                val manager = arFactory.activeManager
                when (call.method) {
                    "resetGrid" -> {
                        manager?.resetGrid()
                        result.success(null)
                    }
                    "setPanelCount" -> {
                        val count = call.argument<Int>("count") ?: 12
                        manager?.requestedPanelCount = count
                        manager?.resetGrid()   // rebuild with new count
                        result.success(null)
                    }
                    "setObstacleCount" -> {
                        val count = call.argument<Int>("count") ?: 0
                        manager?.updateObstacleCount(count)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // Forward Activity lifecycle to ArSceneView so ARCore sessions stay valid
    override fun onResume() {
        super.onResume()
        arFactory.activeManager?.resume()
    }

    override fun onPause() {
        super.onPause()
        arFactory.activeManager?.pause()
    }
}
