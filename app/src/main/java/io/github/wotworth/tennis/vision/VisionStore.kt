package io.github.wotworth.tennis.vision

import android.content.Context

/**
 * Where the app gets Tennis Vision sessions. Until the cloud API is deployed (TV-PH-4) the only
 * source is the bundled sample, made by running the vision pipeline on synthetic footage
 * (assets/vision/sample/). The app makes no network calls for it.
 */
class VisionStore(private val context: Context) {
    private val sample: VisionSession? by lazy { loadSample() }
    val outbox by lazy { Outbox(context.filesDir) }
    val opponents = Opponents()
    /** One-camera tests on real footage (Chris, 17 Nov), bundled in assets/vision/tests/. */
    val tests by lazy { FootageTests(context) }
    private val answered = androidx.compose.runtime.mutableStateListOf<Int>()

    /** "Ball check": crops still to look at (the sample's synthetic ones until the cloud exists). */
    fun checks(showSample: Boolean): List<CheckItem> = if (!showSample) emptyList() else runCatching {
        CheckJson.read(context.assets.open("vision/sample/checks.json").bufferedReader().use { it.readText() })
    }.getOrDefault(emptyList()).filter { it.id !in answered }

    fun checkImage(c: CheckItem): android.graphics.Bitmap? = runCatching {
        context.assets.open("vision/sample/checks/${c.file}").use { android.graphics.BitmapFactory.decodeStream(it) }
    }.getOrNull()

    fun answer(c: CheckItem, a: CheckAnswer) {
        outbox.add("/checks/${c.id}/answer", Feedback.checkBody(c.id, a))
        answered += c.id
    }

    fun flag(session: String, body: org.json.JSONObject) = outbox.add("/sessions/$session/flags", body)

    private val cornersAnswered = androidx.compose.runtime.mutableStateListOf<Int>()

    /** "Court corners" (TV-CAL-21): cameras whose court-line fit the PC doubts (the sample's synthetic one until the cloud exists). */
    fun cornerChecks(showSample: Boolean): List<CornerCheck> {
        // the cloud's requests (TV-API-07, kept by CloudSync), then the sample's synthetic one
        val cloud = CloudSync.cachedCorners(context)?.let { t -> runCatching { CornerJson.read(t) }.getOrNull() }.orEmpty()
            .map { it.copy(file = "cloud:${it.id}") }
        val sample = if (!showSample) emptyList() else runCatching {
            CornerJson.read(context.assets.open("vision/sample/corners.json").bufferedReader().use { it.readText() })
        }.getOrDefault(emptyList())
        return (cloud + sample).filter { it.file !in cornersAnsweredFiles && (it.file.startsWith("cloud:") || it.id !in cornersAnswered) }
    }

    fun cornerImage(c: CornerCheck): android.graphics.Bitmap? = runCatching {
        if (c.file.startsWith("cloud:")) android.graphics.BitmapFactory.decodeFile(CloudSync.cornerPicture(context, c.id).path)
        else context.assets.open("vision/sample/corners/${c.file}").use { android.graphics.BitmapFactory.decodeStream(it) }
    }.getOrNull()

    private val cornersAnsweredFiles = androidx.compose.runtime.mutableStateListOf<String>()

    fun answerCorners(c: CornerCheck, a: CornerAnswer) {
        outbox.add("/calibration/${c.id}/answer", CornerJson.body(a))
        if (c.file.startsWith("cloud:")) { cornersAnsweredFiles += c.file; CloudWork.sendSoon(context) } else cornersAnswered += c.id
    }

    /** Sessions the cloud has (id, headline), as of the last check (CloudSync). */
    fun cloudSessions(): List<Pair<String, String>> = if (CloudConfig.enabled) CloudSync.cachedSessions(context) else emptyList()

    fun sessions(showSample: Boolean): List<VisionSession> = if (showSample) listOfNotNull(sample) else emptyList()

    fun session(id: String): VisionSession? = sample?.takeIf { it.id == id }

    /** Trends: until the cloud is set up, the sample's synthetic trend. */
    fun trends(showSample: Boolean): List<TrendPoint> = if (!showSample) emptyList() else runCatching {
        TrendJson.read(context.assets.open("vision/sample/trends.json").bufferedReader().use { it.readText() })
    }.getOrDefault(emptyList())

    /** A still from a rally's tracer clip (TV-OUT-04), when there is one. */
    fun rallyFrame(id: String, rally: Int): android.graphics.Bitmap? = if (id != SAMPLE_ID) null else runCatching {
        context.assets.open("vision/sample/frames/rally_%02d.jpg".format(rally)).use { android.graphics.BitmapFactory.decodeStream(it) }
    }.getOrNull()

    /** A player's picture for "which one is you?" (TV-PLY-07). */
    fun playerThumb(id: String, label: String): android.graphics.Bitmap? = if (id != SAMPLE_ID) null else runCatching {
        context.assets.open("vision/sample/players/${label.lowercase().replace(' ', '_')}.jpg").use { android.graphics.BitmapFactory.decodeStream(it) }
    }.getOrNull()

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
