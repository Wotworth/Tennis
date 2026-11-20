package io.github.wotworth.tennis.vision

import androidx.compose.ui.geometry.Offset
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt
import kotlin.math.sin

/**
 * Snap a tapped court corner to where the paint really crosses (Chris, 20 Nov; TV-CAL-22).
 *
 * Around the tap, within [radius] picture pixels: the painted lines are the pixels brighter than
 * what is either side of them (up to 17 px wide) and nearly colourless, or less coloured than the
 * court round them. Up to four straight lines are found there; the corner is the crossing of two
 * of them nearest the tap. A court's sizes are measured to the OUTSIDE edges of its lines, so the corner
 * is where the two lines' outside edges cross: each line is moved half its own measured width
 * away from the court. "Away from the court" is the side the other line does not run into (at a
 * corner the baseline runs along the court and the sideline down it). When a line runs on both
 * ways from the crossing (a neighbouring court's line, a tape seam), its side cannot be told and
 * its centre is used. Nothing convincing (no two lines, too little paint, the crossing outside
 * the radius): null, and the tap stands, marked "not snapped".
 */
object CornerSnap {
    data class Line(val angle: Double, val rho: Double, val halfWidth: Double, val votes: Int)
    data class Result(val corner: Offset, val centreCrossing: Offset, val a: Line, val b: Line)

    /** Search radius in picture pixels for a picture [width] wide (2% of the width, at least 24). */
    fun radiusFor(width: Int): Int = max(24, (0.02 * width).roundToInt())

    /**
     * [argb]: the picture's pixels, row by row ([width] x [height]); [tap] in the picture's pixels
     * (x across, y down from the top-left corner, pixel centres at +0.5).
     */
    fun snap(argb: IntArray, width: Int, height: Int, tap: Offset, radius: Int = radiusFor(width)): Result? {
        val x0 = max(0, (tap.x - radius).toInt());  val x1 = min(width - 1, (tap.x + radius).toInt())
        val y0 = max(0, (tap.y - radius).toInt());  val y1 = min(height - 1, (tap.y + radius).toInt())
        val w = x1 - x0 + 1;  val h = y1 - y0 + 1
        if (w < 12 || h < 12) return null
        // brightness and colourfulness in the window
        val lum = DoubleArray(w * h);  val sat = DoubleArray(w * h)
        for (j in 0 until h) for (i in 0 until w) {
            val c = argb[(y0 + j) * width + x0 + i]
            val r = (c shr 16) and 255;  val g = (c shr 8) and 255;  val b = c and 255
            lum[j * w + i] = 0.299 * r + 0.587 * g + 0.114 * b
            val mx = max(r, max(g, b));  val mn = min(r, min(g, b))
            sat[j * w + i] = if (mx == 0) 0.0 else (mx - mn).toDouble() / mx
        }
        // brighter than the surroundings (a box mean 13 px across), colourless: paint
        val bgr = 6
        // a top-hat: brightness above the window's "opening" (the brightest a 17-px square can sit
        // under), so a line up to 17 px wide stands out and the step from court to surround does not
        val open = maxFilter(minFilter(lum, w, h, 8), w, h, 8)
        val satMean = boxMean(sat, w, h, bgr)
        val ridge = DoubleArray(w * h) { lum[it] - open[it] }
        val sorted = ridge.sortedArray()
        val med = sorted[sorted.size / 2]
        val mad = DoubleArray(ridge.size) { abs(ridge[it] - med) }.also { it.sort() }[ridge.size / 2] * 1.4826
        val thr = max(12.0, med + 4 * mad)
        // colourless, or at least less coloured than the court round it: a thin far line is blended
        // with the court's colour by the picture's own blur and coding
        val paint = BooleanArray(w * h) { ridge[it] > thr && (sat[it] < 0.35 || sat[it] < satMean[it] - 0.08) }
        val px = ArrayList<DoubleArray>()          // x, y (picture px), weight
        for (j in 0 until h) for (i in 0 until w) if (paint[j * w + i]) px.add(doubleArrayOf(x0 + i + 0.5, y0 + j + 0.5, ridge[j * w + i] - thr + 1))
        if (px.size < radius) return null
        // up to four lines, strongest first: each the most-voted line through the paint left (votes over
        // angle, 1 degree, and distance from the tap, 1 px), fitted to the paint near it, then its paint
        // taken away. The corner is the crossing nearest the tap of any two of them at 8 degrees or more
        // (a far corner seen from beside the court can be as flat as 17 degrees; the singles corner, an
        // alley along, is the next crossing over, so Chris's tap decides between them)
        val minVotes = max(8, (0.35 * radius).toInt())        // a line at least a third of the window long
        val lines = ArrayList<Line>()
        var rest: List<DoubleArray> = px
        while (lines.size < 4 && rest.size >= minVotes) {
            val v = vote(rest, tap, radius) ?: break
            if (v.third < minVotes) break
            val l = refine(rest, tap, v.first, v.second) ?: break
            lines.add(l)
            rest = rest.filter { abs((it[0] - tap.x) * cos(l.angle) + (it[1] - tap.y) * sin(l.angle) - l.rho) > l.halfWidth + 2 }
        }
        var la: Line? = null;  var lb: Line? = null;  var centre: Offset? = null;  var bestD = Double.MAX_VALUE
        for (i in lines.indices) for (j in i + 1 until lines.size) {
            if (angleGapRad(lines[i].angle, lines[j].angle) < 8 * PI / 180) continue
            val c = cross(lines[i], lines[j], tap) ?: continue
            val d = (c - tap).getDistance().toDouble()
            if (d <= radius && d < bestD) { bestD = d; la = lines[i]; lb = lines[j]; centre = c }
        }
        if (la == null || lb == null || centre == null) return null
        // each line's own width, measured away from the other line (where they cross the paint is both)
        la = la.copy(halfWidth = widthAway(px, tap, la, lb));  lb = lb.copy(halfWidth = widthAway(px, tap, lb, la))
        // which way each line runs from the crossing: the court is on that side of the other line
        val ea = extent(px, la, tap, centre);  val eb = extent(px, lb, tap, centre)
        val oa = outwardShift(la, lb, eb);  val ob = outwardShift(lb, la, ea)
        val corner = cross(la.copy(rho = la.rho + oa), lb.copy(rho = lb.rho + ob), tap) ?: return null
        if ((corner - tap).getDistance() > radius) return null
        return Result(corner, centre, la, lb)
    }

    /** The most-voted line through the paint: (angle of its normal, distance from [o], votes); lines within 8 degrees of [avoid] get none. */
    private fun vote(px: List<DoubleArray>, o: Offset, radius: Int, avoid: Double? = null): Triple<Double, Double, Int>? {
        val nT = 180;  val rMax = (radius * 1.5).toInt() + 2;  val nR = 2 * rMax + 1
        val acc = IntArray(nT * nR)
        for (t in 0 until nT) {
            val th = t * PI / nT
            if (avoid != null && angleGapRad(th, avoid) < 8 * PI / 180) continue
            val c = cos(th);  val s = sin(th)
            for (p in px) {
                val r = ((p[0] - o.x) * c + (p[1] - o.y) * s).roundToInt() + rMax
                if (r in 0 until nR) acc[t * nR + r]++
            }
        }
        var best = -1;  var bv = 0
        for (k in acc.indices) if (acc[k] > bv) { bv = acc[k]; best = k }
        if (best < 0) return null
        return Triple((best / nR) * PI / nT, (best % nR - rMax).toDouble(), bv)
    }

    private fun minFilter(v: DoubleArray, w: Int, h: Int, r: Int) = rankFilter(v, w, h, r, true)
    private fun maxFilter(v: DoubleArray, w: Int, h: Int, r: Int) = rankFilter(v, w, h, r, false)

    /** The smallest (or largest) value in each pixel's (2r+1)-square, rows then columns. */
    private fun rankFilter(v: DoubleArray, w: Int, h: Int, r: Int, lowest: Boolean): DoubleArray {
        fun pick(a: Double, b: Double) = if (lowest) min(a, b) else max(a, b)
        val t = DoubleArray(w * h)
        for (j in 0 until h) for (i in 0 until w) {
            var m = v[j * w + i]
            for (k in max(0, i - r)..min(w - 1, i + r)) m = pick(m, v[j * w + k])
            t[j * w + i] = m
        }
        val o = DoubleArray(w * h)
        for (j in 0 until h) for (i in 0 until w) {
            var m = t[j * w + i]
            for (k in max(0, j - r)..min(h - 1, j + r)) m = pick(m, t[k * w + i])
            o[j * w + i] = m
        }
        return o
    }

    /** The mean of each pixel's (2r+1)-square neighbourhood, cut at the window's edges. */
    private fun boxMean(v: DoubleArray, w: Int, h: Int, r: Int): DoubleArray {
        val sum = DoubleArray((w + 1) * (h + 1))
        for (j in 0 until h) for (i in 0 until w) sum[(j + 1) * (w + 1) + i + 1] = v[j * w + i] + sum[j * (w + 1) + i + 1] + sum[(j + 1) * (w + 1) + i] - sum[j * (w + 1) + i]
        return DoubleArray(w * h) { k ->
            val i = k % w;  val j = k / w
            val a0 = max(0, i - r);  val a1 = min(w, i + r + 1);  val b0 = max(0, j - r);  val b1 = min(h, j + r + 1)
            (sum[b1 * (w + 1) + a1] - sum[b0 * (w + 1) + a1] - sum[b1 * (w + 1) + a0] + sum[b0 * (w + 1) + a0]) / ((a1 - a0) * (b1 - b0))
        }
    }

    private fun angleGapRad(a: Double, b: Double): Double { val d = abs(a - b) % PI; return min(d, PI - d) }

    /** A least-squares line through the paint within a few pixels of a voted line; its half width from the paint's spread across it. */
    private fun refine(px: List<DoubleArray>, o: Offset, theta: Double, rho: Double): Line? {
        var nx = cos(theta);  var ny = sin(theta);  var r = rho
        var near: List<DoubleArray> = emptyList()
        repeat(2) {
            near = px.filter { abs((it[0] - o.x) * nx + (it[1] - o.y) * ny - r) <= 4.0 }
            if (near.size < 6) return null
            var sw = 0.0;  var mx = 0.0;  var my = 0.0
            for (p in near) { sw += p[2]; mx += p[2] * p[0]; my += p[2] * p[1] }
            mx /= sw;  my /= sw
            var sxx = 0.0;  var syy = 0.0;  var sxy = 0.0
            for (p in near) { val dx = p[0] - mx; val dy = p[1] - my; sxx += p[2] * dx * dx; syy += p[2] * dy * dy; sxy += p[2] * dx * dy }
            val dir = 0.5 * atan2(2 * sxy, sxx - syy)           // along the line
            nx = -sin(dir);  ny = cos(dir)
            r = (mx - o.x) * nx + (my - o.y) * ny
        }
        val d = near.map { (it[0] - o.x) * nx + (it[1] - o.y) * ny - r }.sorted()
        val lo = d[(0.05 * (d.size - 1)).toInt()];  val hi = d[(0.95 * (d.size - 1)).toInt()]
        return Line(atan2(ny, nx), r, max(0.5, (hi - lo + 1) / 2), near.size)
    }

    /** Half [l]'s width: the spread across it of the paint within 12 px of it, leaving out paint near [other]. */
    private fun widthAway(px: List<DoubleArray>, o: Offset, l: Line, other: Line): Double {
        val d = ArrayList<Double>()
        for (p in px) {
            val dl = (p[0] - o.x) * cos(l.angle) + (p[1] - o.y) * sin(l.angle) - l.rho
            val dOther = (p[0] - o.x) * cos(other.angle) + (p[1] - o.y) * sin(other.angle) - other.rho
            if (abs(dl) <= 12 && abs(dOther) > other.halfWidth + 6) d.add(dl)
        }
        if (d.size < 6) return l.halfWidth
        d.sort()
        val lo = d[(0.03 * (d.size - 1)).toInt()];  val hi = d[(0.97 * (d.size - 1)).toInt()]
        return max(0.5, (hi - lo + 1) / 2)
    }

    private fun cross(a: Line, b: Line, o: Offset): Offset? {
        val a1 = cos(a.angle);  val b1 = sin(a.angle);  val a2 = cos(b.angle);  val b2 = sin(b.angle)
        val det = a1 * b2 - a2 * b1
        if (abs(det) < 1e-6) return null
        val x = (a.rho * b2 - b.rho * b1) / det;  val y = (a1 * b.rho - a2 * a.rho) / det
        return Offset((o.x + x).toFloat(), (o.y + y).toFloat())
    }

    /** +1 or -1: the way along the line most of its paint runs from the crossing; 0 when both ways (a line that runs through). */
    private fun extent(px: List<DoubleArray>, l: Line, o: Offset, c: Offset): Int {
        val nx = cos(l.angle);  val ny = sin(l.angle);  val ux = -ny;  val uy = nx
        var plus = 0;  var minus = 0
        for (p in px) {
            if (abs((p[0] - o.x) * nx + (p[1] - o.y) * ny - l.rho) > l.halfWidth + 1.5) continue
            val t = (p[0] - c.x) * ux + (p[1] - c.y) * uy
            if (t > l.halfWidth + 2) plus++ else if (t < -l.halfWidth - 2) minus++
        }
        return when {
            plus >= 3 * max(minus, 1) -> 1
            minus >= 3 * max(plus, 1) -> -1
            else -> 0
        }
    }

    /** How far to move [l] (along its own normal) to its outside edge: half its width, away from where [other] runs. */
    private fun outwardShift(l: Line, other: Line, otherExtent: Int): Double {
        if (otherExtent == 0) return 0.0
        val nx = cos(l.angle);  val ny = sin(l.angle)
        val ox = -sin(other.angle) * otherExtent;  val oy = cos(other.angle) * otherExtent   // where the other line runs
        val side = nx * ox + ny * oy                                                        // + : the court is on the normal's side
        return if (side > 0) -l.halfWidth else l.halfWidth
    }
}
