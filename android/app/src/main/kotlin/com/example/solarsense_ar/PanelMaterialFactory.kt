package com.example.solarsense_ar

import android.content.Context
import com.google.ar.sceneform.math.Vector3
import com.google.ar.sceneform.rendering.Color
import com.google.ar.sceneform.rendering.MaterialFactory
import com.google.ar.sceneform.rendering.ModelRenderable
import com.google.ar.sceneform.rendering.ShapeFactory

/**
 * Builds and caches the nav-blue solar panel material + box renderable.
 * Panel dimensions: W=1.70m  H=0.04m (solid thickness)  D=1.14m
 */
object PanelMaterialFactory {

    const val WIDTH  = 1.70f
    const val HEIGHT = 0.04f
    const val DEPTH  = 1.14f

    private val PANEL_COLOR = Color(0.05f, 0.12f, 0.35f)
    private var cached: ModelRenderable? = null

    fun build(context: Context): java.util.concurrent.CompletableFuture<ModelRenderable> {
        cached?.let {
            return java.util.concurrent.CompletableFuture.completedFuture(it)
        }
        return MaterialFactory.makeOpaqueWithColor(context, PANEL_COLOR)
            .thenCompose { material ->
                material.setFloat("roughness",   0.55f)
                material.setFloat("metallic",    0.30f)
                material.setFloat("reflectance", 0.40f)

                val renderable = ShapeFactory.makeCube(
                    Vector3(WIDTH, HEIGHT, DEPTH),
                    Vector3(0f, HEIGHT / 2f, 0f),
                    material,
                )
                cached = renderable
                @Suppress("UnusedDataClassCopyResult")
                java.util.concurrent.CompletableFuture.completedFuture(renderable)
            }
    }

    fun invalidate() { cached = null }
}
