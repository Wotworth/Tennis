package io.github.wotworth.tennis.vision

import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import org.json.JSONArray
import org.json.JSONObject

/**
 * "Court corners" (Chris, 19 Nov; TV-CAL-21, TV-CAL-22). When the PC's court-line fit for a camera
 * is doubtful it holds the session and sends that camera's picture of the empty court with the
 * fitted lines. Here Chris taps the four corners of the doubles court, or says the drawn lines are
 * right; the PC pulls the answer and runs the session on. The app only posts what was tapped.
 *
 * Every position is in the sent picture's pixels, x across and y down from its top-left corner.
 */
data class CornerCheck(
    val id: Int, val sessionId: String, val cam: Int, val file: String, val width: Int, val height: Int,
    /** The share of the fitted court's lines with paint under them, 0 to 1. */
    val support: Double,
    /** "lines": the lines do not back the fit. "taps": the last taps did not make a court. */
    val reason: String,
    /** The fitted court as drawn through the lens: each line a run of points. */
    val lines: List<List<Offset>>,
)

sealed interface CornerAnswer {
    data class Corners(val points: List<Offset>) : CornerAnswer
    data object Accepted : CornerAnswer
}

object CornerJson {
    /** The bundled sample ({"checks": [...]}) or the cloud's list ([...]). */
    fun read(text: String): List<CornerCheck> {
        val t = text.trim()
        val a = if (t.startsWith("[")) JSONArray(t) else JSONObject(t).getJSONArray("checks")
        return (0 until a.length()).map { a.getJSONObject(it) }.map { o ->
            val ls = o.getJSONArray("lines")
            CornerCheck(o.getInt("id"), o.getString("sessionId"), o.getInt("cam"),
                o.optString("file", o.optString("picturePath")), o.getInt("width"), o.getInt("height"),
                o.optDouble("support", 0.0), o.optString("reason", "lines"),
                (0 until ls.length()).map { i ->
                    val l = ls.getJSONArray(i)
                    (0 until l.length()).map { j -> l.getJSONArray(j).let { p -> Offset(p.getDouble(0).toFloat(), p.getDouble(1).toFloat()) } }
                })
        }
    }

    /** Exactly what the Worker accepts: {"answer": "accepted"} or {"answer": "corners", "corners": [[x, y] x 4]}. */
    fun body(a: CornerAnswer): JSONObject = when (a) {
        CornerAnswer.Accepted -> JSONObject().put("answer", "accepted")
        is CornerAnswer.Corners -> {
            require(a.points.size == 4) { "four corners" }
            JSONObject().put("answer", "corners").put("corners", JSONArray().also { arr ->
                a.points.forEach { p -> arr.put(JSONArray().put(round1(p.x)).put(round1(p.y))) }
            })
        }
    }

    private fun round1(v: Float): Double = Math.round(v * 10.0) / 10.0
}

/** Where a touch on the zoomed, panned picture falls in the picture's own pixels, and back. */
object CornerGeometry {
    /** [touch] in the picture box (px); [box] its size; [zoom] and [pan] as drawn (scale about the top-left, then shift). */
    fun toPicture(touch: Offset, box: Size, zoom: Float, pan: Offset, width: Int, height: Int): Offset {
        val x = (touch.x - pan.x) / zoom / box.width * width
        val y = (touch.y - pan.y) / zoom / box.height * height
        return Offset(x.coerceIn(0f, width.toFloat()), y.coerceIn(0f, height.toFloat()))
    }

    fun toBox(p: Offset, box: Size, zoom: Float, pan: Offset, width: Int, height: Int): Offset =
        Offset(p.x / width * box.width * zoom + pan.x, p.y / height * box.height * zoom + pan.y)

    /** A zoom change about the fingers' middle point [c], then their shift [d]; the picture never leaves its box. */
    fun pinch(zoom: Float, pan: Offset, z: Float, c: Offset, d: Offset, box: Size, maxZoom: Float): Pair<Float, Offset> {
        val nz = (zoom * z).coerceIn(1f, maxZoom)
        val np = if (nz == 1f) Offset.Zero else (pan - c) * (nz / zoom) + c + d
        return nz to clamp(np, nz, box)
    }

    fun clamp(pan: Offset, zoom: Float, box: Size): Offset =
        Offset(pan.x.coerceIn(box.width * (1 - zoom), 0f), pan.y.coerceIn(box.height * (1 - zoom), 0f))
}

/** How many corners are tapped, in words (the page shows no counts in digits). */
fun cornersTappedText(n: Int): String = when (n) {
    0 -> "none tapped yet"
    1 -> "one tapped"
    2 -> "two tapped"
    3 -> "three tapped"
    else -> "all four tapped"
}
