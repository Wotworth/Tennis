package io.github.wotworth.tennis.vision

import android.content.Context

/**
 * Where the app gets Tennis Vision sessions. Until the cloud API is deployed (TV-PH-4) the only
 * source is the bundled sample, made by running the vision pipeline on synthetic footage
 * (assets/vision/sample/). The app makes no network calls for it.
 */
class VisionStore(private val context: Context) {
    private val sample: VisionSession? by lazy { loadSample() }

    fun sessions(showSample: Boolean): List<VisionSession> = if (showSample) listOfNotNull(sample) else emptyList()

    fun session(id: String): VisionSession? = sample?.takeIf { it.id == id }

    private fun loadSample(): VisionSession? = runCatching {
        fun read(n: String) = context.assets.open("vision/sample/$n").bufferedReader().use { it.readText() }
        fun maybe(n: String) = runCatching { read(n) }.getOrNull()
        VisionJson.session(SAMPLE_ID, read("session.json"), read("shots.json"), read("rallies.json"),
            maybe("trajectories.json"), sample = true, hr = maybe("hr.json"))
    }.getOrNull()

    companion object {
        const val SAMPLE_ID = "sample"
    }
}
