package io.github.wotworth.tennis.vision

import android.content.Context

/**
 * The accuracy report's numbers (Chris, 22 Nov, item 14): what tools/groundTruthReport.m writes
 * beside its report (forApp), one file per test session. Any test not done comes as [] or is
 * missing; MATLAB writes a one-element list as a lone object, and a missing number as null.
 * Distances in cm, speeds in mph, spin effect in ft, as given.
 */
data class AccuracyResult(
    val session: String,
    val synthetic: Boolean,
    val cameras: List<CameraCheck>,
    val drop: DropCheck?,
    val still: List<StillCheck>,
    val targets: List<TargetCheck>,
    val machine: List<MachineCheck>,
    val spin: SpinCheck?,
)

data class CameraCheck(val cam: Int, val found: List<Double?>, val taped: List<Double?>, val errCm: Double?)
data class DropCheck(val n: Int?, val g: Double?, val gSpread: Double?, val gTruth: Double?, val heightM: Double?, val heightSpreadM: Double?, val heightTruthM: Double?)
data class StillCheck(val name: String, val found: Boolean, val errCm: Double?, val gapCm: Double?)
data class TargetCheck(val name: String, val n: Int?, val medianCm: Double?, val worstCm: Double?)
data class MachineCheck(val setting: String, val n: Int?, val speedMph: Double?, val speedSdMph: Double?, val spinFt: Double?, val spinSdFt: Double?, val landSdCm: Double?)
data class SpinRow(val ball: Int, val stripeRpm: Double?, val stripeSdRpm: Double?, val systemRpm: Double?, val systemSdRpm: Double?, val inside: Boolean?)
data class SpinCheck(val medianDiffRpm: Double?, val rows: List<SpinRow>)

object AccuracyJson {
    fun read(text: String): AccuracyResult {
        val m = MiniJson.parse(text).obj() ?: error("not a JSON object")
        val drop = m["drop"].obj()?.let { d ->
            DropCheck(d.num("n")?.toInt(), d.num("g"), d.num("gSpread"), d.num("gTruth") ?: 9.81, d.num("heightM"), d.num("heightSpreadM"), d.num("heightTruthM"))
        }
        val spin = m["spin"].obj()?.let { s ->
            SpinCheck(s.num("medianDiffRpm"), s["rows"].objs().mapIndexed { i, r ->
                SpinRow(r.num("ball")?.toInt() ?: (i + 1), r.num("stripeRpm"), r.num("stripeSdRpm"), r.num("systemRpm"), r.num("systemSdRpm"), r.bool("inside"))
            })
        }
        return AccuracyResult(
            session = m.text("session") ?: "",
            synthetic = m.bool("synthetic") ?: false,
            cameras = m["cameras"].objs().mapIndexed { i, c -> CameraCheck(c.num("cam")?.toInt() ?: (i + 1), c["found"].nums(), c["taped"].nums(), c.num("errCm")) },
            drop = drop,
            still = m["still"].objs().map { StillCheck(it.text("name") ?: "", it.bool("found") ?: false, it.num("errCm"), it.num("gapCm")) },
            targets = m["targets"].objs().map { TargetCheck(it.text("name") ?: "", it.num("n")?.toInt(), it.num("medianCm"), it.num("worstCm")) },
            machine = m["machine"].objs().map {
                MachineCheck(it.text("setting") ?: "", it.num("n")?.toInt(), it.num("speedMph"), it.num("speedSdMph"), it.num("spinFt"), it.num("spinSdFt"), it.num("landSdCm"))
            },
            spin = spin?.takeIf { it.rows.isNotEmpty() || it.medianDiffRpm != null },
        )
    }

    /** Newest session first; on the same day, real results before the synthetic sample. */
    fun newestFirst(list: List<AccuracyResult>): List<AccuracyResult> =
        list.sortedWith(compareByDescending<AccuracyResult> { it.session }.thenBy { it.synthetic })
}

/** The results bundled in assets/vision/accuracy/ (the PC's files, added to the app by hand for now). */
class AccuracyStore(private val context: Context) {
    fun all(): List<AccuracyResult> = AccuracyJson.newestFirst(
        (runCatching { context.assets.list(DIR) }.getOrNull() ?: emptyArray()).filter { it.endsWith(".json") }.mapNotNull { n ->
            runCatching { AccuracyJson.read(context.assets.open("$DIR/$n").bufferedReader().use { it.readText() }) }.getOrNull()
        },
    )

    companion object { const val DIR = "vision/accuracy" }
}
