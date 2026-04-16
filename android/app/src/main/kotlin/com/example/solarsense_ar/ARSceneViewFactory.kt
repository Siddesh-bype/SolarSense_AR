package com.example.solarsense_ar

import android.content.Context
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/**
 * Flutter PlatformViewFactory that vends [ARSceneManager] instances.
 * Registered in [MainActivity] under the view type "com.solarsense.ar/arview".
 *
 * The factory keeps a reference to the last-created manager so the Activity
 * can forward lifecycle calls (resume/pause) to it.
 */
class ARSceneViewFactory : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    var activeManager: ARSceneManager? = null
        private set

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val manager = ARSceneManager(context)
        activeManager = manager
        return manager
    }
}
