package io.github.wotworth.tennis.vision

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

/**
 * A one-camera footage test (Chris, 17 Nov): the vision pipeline's single-camera run on real
 * footage (tv.pipeline.runSingle, tv.out.singleTest), bundled in assets/vision/tests/<id>/.
 * No 3D flights, speeds or spin (they need two cameras); it shows how well the code found the
 * court lines, the ball, bounces and players.
 */
data class FootageTest(
    val id: String,
    val title: String,
    val date: String,
    val source: String,
    val lengthS: Double,
    val fps: Double,
    val court: TestCourt,
    val clips: List<TestClip>,
    val ball: TestBall,
    val bounces: List<TestBounce>,
    val players: TestPlayers,
    val frames: List<TestFrame>,
    val notes: List<String>,
)

data class TestCourt(
    val image: String,
    val imageWidth: Int,
    val imageHeight: Int,
    val lines: List<List<Pair<Float, Float>>>,
    val net: List<Pair<Float, Float>>,
    val hfovDeg: Double,
    val camera: List<Double>,
    val lineRmsPx: Double,
    val paintShare: Double,
    val cornersOutOfView: List<String>,
    val scorecardMedianPx: Double?,
    val scorecardPoints: List<Double>,
)

data class TestClip(val index: Int, val startS: Double, val lengthS: Double, val frames: Int, val framesWithBall: Int, val tracks: Int, val bounces: Int)

data class TestCheck(val framesChecked: Int, val ballVisible: Int, val found: Int, val missed: Int, val spotsChecked: Int, val spotsBall: Int, val note: String)

data class TestBall(val framesInClips: Int, val framesWithBall: Int, val candidates: Int, val tracks: Int, val check: TestCheck?)

data class TestBounce(val clip: Int, val t: Double, val x: Double, val y: Double, val call: String, val marginM: Double)

data class TestPlayers(val samples: Int, val withTwoOnCourt: Int, val withOneOrMore: Int)

data class TestFrame(val file: String, val clip: Int, val t: Double, val verdict: String, val caption: String)

object FootageTestJson {
    private fun JSONArray.objs() = (0 until length()).map { getJSONObject(it) }
    private fun JSONObject.list(k: String): JSONArray = optJSONArray(k) ?: optJSONObject(k)?.let { JSONArray().put(it) } ?: JSONArray()
    private fun pts(a: JSONArray?): List<Pair<Float, Float>> = if (a == null) emptyList() else
        (0 until a.length()).map { a.getJSONArray(it).let { p -> p.getDouble(0).toFloat() to p.getDouble(1).toFloat() } }

    fun read(id: String, text: String): FootageTest {
        val o = JSONObject(text)
        val c = o.getJSONObject("court")
        val lines = c.optJSONArray("lines")?.let { a -> (0 until a.length()).map { pts(a.getJSONArray(it)) } } ?: emptyList()
        val sc = c.optJSONObject("scorecard")
        val corners = c.optJSONArray("cornersOutOfView")?.let { a -> (0 until a.length()).map { a.getString(it) } }
            ?: c.optString("cornersOutOfView", "").takeIf { it.isNotBlank() }?.let { listOf(it) } ?: emptyList()
        val b = o.getJSONObject("ball")
        val ck = b.optJSONObject("check")?.let {
            TestCheck(it.getInt("framesChecked"), it.getInt("ballVisible"), it.getInt("found"), it.getInt("missed"),
                it.getInt("spotsChecked"), it.getInt("spotsBall"), it.optString("note"))
        }
        val p = o.getJSONObject("players")
        val v = o.getJSONObject("video")
        return FootageTest(
            id = id, title = o.optString("title"), date = o.optString("date"), source = o.optString("source"),
            lengthS = v.getDouble("lengthS"), fps = v.getDouble("fps"),
            court = TestCourt(
                c.getString("image"), c.getInt("imageWidth"), c.getInt("imageHeight"), lines, pts(c.optJSONArray("net")),
                c.getDouble("hfovDeg"), c.getJSONArray("camera").let { a -> (0 until a.length()).map { a.getDouble(it) } },
                c.getDouble("lineRmsPx"), c.getDouble("paintShare"), corners,
                sc?.optDouble("medianPx")?.takeIf { !it.isNaN() },
                sc?.optJSONArray("perPointPx")?.let { a -> (0 until a.length()).map { a.getDouble(it) } } ?: emptyList(),
            ),
            clips = o.list("clips").objs().map {
                TestClip(it.getInt("index"), it.getDouble("startS"), it.getDouble("lengthS"), it.getInt("frames"),
                    it.getInt("framesWithBall"), it.getInt("tracks"), it.getInt("bounces"))
            },
            ball = TestBall(b.getInt("framesInClips"), b.getInt("framesWithBall"), b.getInt("candidates"), b.getInt("tracks"), ck),
            bounces = o.list("bounces").objs().map {
                TestBounce(it.getInt("clip"), it.getDouble("t"), it.getDouble("x"), it.getDouble("y"), it.getString("call"), it.getDouble("marginM"))
            },
            players = TestPlayers(p.getInt("samples"), p.getInt("withTwoOnCourt"), p.getInt("withOneOrMore")),
            frames = o.list("frames").objs().map {
                TestFrame(it.getString("file"), it.getInt("clip"), it.getDouble("t"), it.optString("verdict"), it.optString("caption"))
            },
            notes = o.optJSONArray("notes")?.let { a -> (0 until a.length()).map { a.getString(it) } }
                ?: o.optString("notes", "").takeIf { it.isNotBlank() }?.let { listOf(it) } ?: emptyList(),
        )
    }
}

/**
 * The bundled footage tests (assets/vision/tests/<id>/test.json), named one per line in
 * assets/vision/tests/index.txt (listing an asset folder is not reliable on every runtime).
 */
class FootageTests(private val context: Context) {
    private fun ids(): List<String> = runCatching {
        context.assets.open("vision/tests/index.txt").bufferedReader().use { r -> r.readLines().map { it.trim() }.filter { it.isNotEmpty() } }
    }.getOrDefault(emptyList())

    val all: List<FootageTest> by lazy {
        ids().sorted().mapNotNull { id ->
            runCatching {
                FootageTestJson.read(id, context.assets.open("vision/tests/$id/test.json").bufferedReader().use { it.readText() })
            }.getOrNull()
        }
    }

    fun get(id: String) = all.firstOrNull { it.id == id }

    fun image(id: String, file: String): android.graphics.Bitmap? = runCatching {
        context.assets.open("vision/tests/$id/$file").use { android.graphics.BitmapFactory.decodeStream(it) }
    }.getOrNull()
}
