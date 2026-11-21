package io.github.wotworth.tennis.vision

import java.io.File

/**
 * Tuesday's field notes (Chris, 22 Nov, item 9; docs/USER-MANUAL.md 16.3 and 16.4): what Chris
 * measures at the court, written as the JSON file the MATLAB accuracy report reads, with exactly
 * the keys and nesting of vision/groundtruth/template.json. Plain Kotlin, no Android.
 *
 * Court axes (as the template): x along the court, the near baseline (the cameras' side) at
 * x = -11.885; y across, the cameras' side fence at negative y; z up. Distances in metres.
 * A number not filled in yet is null, written as null.
 */
data class FieldNotes(
    /** The session day, yyyy-mm-dd; also the file's name. */
    val session: String,
    /** Anything else Chris writes down (lens, shutter, battery, heat). */
    val chrisNote: String = "",
    val cameras: List<NoteCamera> = listOf(NoteCamera(1, atEnd = "near"), NoteCamera(2, atEnd = "far")),
    val court: NoteCourt = NoteCourt(),
    val still: NoteStill = NoteStill(),
    val drops: NoteDrops = NoteDrops(),
    val targets: NoteTargets = NoteTargets(),
    val machine: List<MachineClip> = DEFAULT_MACHINE,
    /** Optional (manual 16.3 step 9): null when the striped-ball clip wasn't done. */
    val spin: SpinTruth? = null,
) {
    companion object {
        const val HALF_LENGTH = 11.885
        const val HALF_DOUBLES = 5.485
        const val HALF_SINGLES = 4.115
        const val SERVICE = 6.40
        const val BALL_RADIUS = 0.0335
        /** The release height is measured to the ball's bottom (manual 16.3 step 5: 2.00 m). */
        const val DROP_BOTTOM_M = 2.00

        const val AXES_NOTE = "Filled from Chris's measurements (USER-MANUAL section 16). Distances in metres. Court axes: x along the court " +
            "(the near baseline, the cameras' side, at x = -11.885), y across (the cameras' side fence at negative y), z up."
        private const val CHRIS = "\nChris: "
        const val SPIN_NOTE = "Optional (manual 16.3 step 9, clip 8): six striped balls fed by the machine at one setting, filmed side-on " +
            "by the Hero 7 at 1080p240 from about 3 m. clip: the GoPro clip of the same feeds. spin: top or back, as the machine is set " +
            "(it settles which way the stripe turns)."

        /** Manual 16.3 step 7: four settings, one clip each. */
        val DEFAULT_MACHINE = listOf(
            MachineClip("clip4", "medium flat"),
            MachineClip("clip5", "medium topspin"),
            MachineClip("clip6", "slow slice"),
            MachineClip("clip7", "fast topspin"),
        )
        const val SPIN_CLIP = "clip8"
        const val SPIN_SETTING = "striped balls, topspin"

        fun fromJson(text: String): FieldNotes = fromTree(MiniJson.parse(text).obj() ?: error("not a JSON object"))

        fun fromTree(m: Map<String, Any?>): FieldNotes {
            val d = FieldNotes(m.text("session") ?: "")
            val note = m.text("note") ?: ""
            val chris = when {
                note.startsWith(AXES_NOTE) -> note.removePrefix(AXES_NOTE).removePrefix(CHRIS.trimEnd()).trimStart()
                else -> note
            }
            val cams = m["cameras"].objs().map {
                NoteCamera((it.num("cam") ?: 1.0).toInt(), it.num("heightM"), it.num("fromDoublesSidelineM"), it.num("beyondBaselineM"), it.text("atEnd") ?: "near")
            }
            val court = m["court"].obj()?.let { NoteCourt(it.num("baselineWidthM"), it.num("serviceLineWidthM"), it.num("doublesWidthM")) } ?: d.court
            val still = m["stillBalls"].obj()?.let { s ->
                NoteStill(s.text("clip") ?: "clip1", s.num("atS"), netTape = s["balls"].objs().any { it.text("name") == NET_TAPE })
            } ?: d.still
            val drops = m["drops"].obj()?.let { s ->
                NoteDrops(s.text("clip") ?: "clip2", s.num("releaseHeightM"),
                    s["spots"].objs().map { DropSpot(it.text("name") ?: "", it.num("x") ?: 0.0, it.num("y") ?: 0.0, it.num("count")?.toInt()) })
            } ?: d.drops
            val targets = m["targets"].obj()?.let { s ->
                NoteTargets(s.text("clip") ?: "clip3", s["spots"].objs().map { t ->
                    val y = t.num("y")
                    val side = when {
                        t.num("fromSidelineM") == null && (y == null || y == 0.0) -> TargetSide.CENTRE
                        y != null && y > 0 -> TargetSide.OTHER
                        else -> TargetSide.CAMERAS
                    }
                    Target(t.text("name") ?: "", side, t.num("fromBaselineM"), if (side == TargetSide.CENTRE) null else t.num("fromSidelineM"))
                })
            } ?: d.targets
            val machine = m["machine"].objs().map { c ->
                val p = c["position"].obj()
                val x = p?.num("x"); val y = p?.num("y")
                MachineClip(c.text("clip") ?: "", c.text("setting") ?: "", c.num("speedDial"), c.num("spinDial"), c.num("feedS"), c.num("elevationDeg"),
                    alongM = x?.let { round4(kotlin.math.abs(it - HALF_LENGTH)) }, behind = x == null || x >= HALF_LENGTH,
                    acrossM = y?.let { kotlin.math.abs(it) }, acrossOther = (y ?: 0.0) > 0)
            }
            val spin = m["spinTruth"].obj()?.let { SpinTruth(it.text("clip") ?: SPIN_CLIP, it.text("file") ?: "", it.num("balls")?.toInt(), it.text("spin") ?: "top") }
            return FieldNotes(d.session, chris, if (cams.isEmpty()) d.cameras else cams, court, still, drops, targets,
                if (m.containsKey("machine")) machine else d.machine, spin)
        }

        /** To 0.1 mm, as written to the file. */
        fun round4(v: Double) = Math.round(v * 1e4) / 1e4

        /** Names the form and the test use. */
        const val NET_TAPE = "net tape at the centre strap"
    }

    /** The JSON tree, keys in the template's order. */
    fun toTree(): Map<String, Any?> = linkedMapOf(
        "session" to session,
        "note" to (if (chrisNote.isBlank()) AXES_NOTE else AXES_NOTE + CHRIS + chrisNote.trim()),
        "cameras" to cameras.map {
            linkedMapOf("cam" to it.cam, "heightM" to it.heightM, "fromDoublesSidelineM" to it.fromDoublesSidelineM,
                "beyondBaselineM" to it.beyondBaselineM, "atEnd" to it.atEnd)
        },
        "court" to linkedMapOf("baselineWidthM" to court.baselineWidthM, "serviceLineWidthM" to court.serviceLineWidthM, "doublesWidthM" to court.doublesWidthM),
        "stillBalls" to linkedMapOf("clip" to still.clip, "atS" to still.atS,
            "balls" to still.balls.map { linkedMapOf("name" to it.name, "x" to it.x, "y" to it.y, "z" to it.z) }),
        "drops" to linkedMapOf("clip" to drops.clip, "releaseHeightM" to drops.releaseHeightM,
            "spots" to drops.spots.map { linkedMapOf("name" to it.name, "x" to it.x, "y" to it.y, "count" to it.count) }),
        // a centre-line target has no distance from a sideline: written as null, so every spot
        // keeps the same keys (MATLAB's report joins the spots into one struct array)
        "targets" to linkedMapOf("clip" to targets.clip, "spots" to targets.spots.map {
            linkedMapOf("name" to it.name, "fromBaselineM" to it.fromBaselineM, "fromSidelineM" to it.fromSidelineM, "x" to it.x, "y" to it.y)
        }),
    ).also { t ->
        spin?.let { t["spinTruth"] = linkedMapOf("clip" to it.clip, "file" to it.file, "balls" to it.balls, "spin" to it.spin, "note" to SPIN_NOTE) }
        t["machine"] = machine.map {
            linkedMapOf("clip" to it.clip, "setting" to it.setting, "speedDial" to it.speedDial, "spinDial" to it.spinDial,
                "feedS" to it.feedS, "elevationDeg" to it.elevationDeg, "position" to linkedMapOf("x" to it.x, "y" to it.y))
        }
    }

    fun toJson(): String = MiniJson.write(toTree(), decimals = 4)

    /** The striped-ball clip on: adds its machine clip (dials to fill in) if there isn't one. Off: drops that clip if nothing was filled in. */
    fun withSpin(on: Boolean): FieldNotes = if (on) {
        copy(spin = spin ?: SpinTruth(), machine = if (machine.any { it.clip == SPIN_CLIP }) machine else machine + MachineClip(SPIN_CLIP, SPIN_SETTING,
            alongM = machine.lastOrNull()?.alongM, behind = machine.lastOrNull()?.behind ?: true, acrossM = machine.lastOrNull()?.acrossM ?: 0.0,
            acrossOther = machine.lastOrNull()?.acrossOther ?: false))
    } else {
        copy(spin = null, machine = machine.filterNot { it.clip == SPIN_CLIP && it.setting == SPIN_SETTING && it.isBlank })
    }
}

data class NoteCamera(
    val cam: Int,
    val heightM: Double? = null,
    /** Straight across from the doubles sideline to the camera. */
    val fromDoublesSidelineM: Double? = null,
    /** Along, from the baseline line extended to the camera. */
    val beyondBaselineM: Double? = null,
    /** "near" or "far". */
    val atEnd: String = "near",
)

data class NoteCourt(val baselineWidthM: Double? = null, val serviceLineWidthM: Double? = null, val doublesWidthM: Double? = null)

data class StillBall(val name: String, val x: Double, val y: Double, val z: Double)

/** Clip 1: six balls at fixed spots (manual 16.3 step 4); the net-tape ball is skipped if it won't balance. */
data class NoteStill(val clip: String = "clip1", val atS: Double? = null, val netTape: Boolean = true) {
    val balls: List<StillBall> get() = ALL.filter { netTape || it.name != FieldNotes.NET_TAPE }

    companion object {
        private const val R = FieldNotes.BALL_RADIUS
        val ALL = listOf(
            // inside edge of the near baseline: the ball 12 cm in from the baseline's outer edge
            StillBall("near centre mark", -(FieldNotes.HALF_LENGTH - 0.12), 0.0, R),
            StillBall("near T", -FieldNotes.SERVICE, 0.0, R),
            StillBall("far T", FieldNotes.SERVICE, 0.0, R),
            StillBall("far service line at the singles sideline", FieldNotes.SERVICE, -FieldNotes.HALF_SINGLES, R),
            // on the net tape at the centre strap: 0.914 m + the ball's radius
            StillBall(FieldNotes.NET_TAPE, 0.0, 0.0, 0.948),
            StillBall("1 m inside the near doubles corner", -(FieldNotes.HALF_LENGTH - 1.0), -(FieldNotes.HALF_DOUBLES - 1.0), R),
        )
    }
}

data class DropSpot(val name: String, val x: Double, val y: Double, val count: Int?)

/** Clip 2: drops from 2.00 m (to the ball's bottom); releaseHeightM is to the ball's centre. */
data class NoteDrops(
    val clip: String = "clip2",
    val releaseHeightM: Double? = FieldNotes.round4(FieldNotes.DROP_BOTTOM_M + FieldNotes.BALL_RADIUS),
    val spots: List<DropSpot> = DEFAULTS,
) {
    companion object {
        val DEFAULTS = listOf(
            DropSpot("net post", 0.0, -5.4, 3),
            DropSpot("near service box centre", -FieldNotes.SERVICE / 2, -2.06, 3),
            DropSpot("far T", FieldNotes.SERVICE, 0.0, 3),
        )
    }
}

enum class TargetSide { CAMERAS, CENTRE, OTHER }

/**
 * A taped cross at the far end, measured from the far baseline and from the doubles sideline on
 * [side]. x = 11.885 - fromBaseline; y = -(5.485 - fromSideline) on the cameras' side,
 * +(5.485 - fromSideline) on the other side, 0 on the centre line.
 */
data class Target(val name: String, val side: TargetSide, val fromBaselineM: Double?, val fromSidelineM: Double?) {
    val x: Double? get() = fromBaselineM?.let { FieldNotes.HALF_LENGTH - it }
    val y: Double? get() = when (side) {
        TargetSide.CENTRE -> 0.0
        TargetSide.CAMERAS -> fromSidelineM?.let { -(FieldNotes.HALF_DOUBLES - it) }
        TargetSide.OTHER -> fromSidelineM?.let { FieldNotes.HALF_DOUBLES - it }
    }
}

/** Clip 3 (manual 16.3 step 6): the six crosses, at the distances the manual gives. */
data class NoteTargets(val clip: String = "clip3", val spots: List<Target> = DEFAULTS) {
    companion object {
        private val BOX_FROM_BASELINE = FieldNotes.round4(FieldNotes.HALF_LENGTH - FieldNotes.SERVICE / 2)     // 8.685
        private val BOX_FROM_SIDELINE = FieldNotes.round4(FieldNotes.HALF_DOUBLES - FieldNotes.HALF_SINGLES / 2)  // 3.4275
        val DEFAULTS = listOf(
            Target("far left corner", TargetSide.CAMERAS, 0.5, 0.5),
            Target("far right corner", TargetSide.OTHER, 0.5, 0.5),
            Target("far centre line, 1 m short of the baseline", TargetSide.CENTRE, 1.0, null),
            Target("far left service box centre", TargetSide.CAMERAS, BOX_FROM_BASELINE, BOX_FROM_SIDELINE),
            Target("far right service box centre", TargetSide.OTHER, BOX_FROM_BASELINE, BOX_FROM_SIDELINE),
            Target("far centre line, 50 cm short of the service line", TargetSide.CENTRE, FieldNotes.round4(FieldNotes.HALF_LENGTH - FieldNotes.SERVICE + 0.5), null),
        )
    }
}

/**
 * One machine clip (manual 16.3 step 7). The machine's place: [alongM] from the far centre mark
 * along the court ([behind] the baseline or inside the court) and [acrossM] from the centre line
 * ([acrossOther]: towards the other side, else towards the cameras' side).
 */
data class MachineClip(
    val clip: String,
    val setting: String,
    val speedDial: Double? = null,
    val spinDial: Double? = null,
    val feedS: Double? = null,
    val elevationDeg: Double? = null,
    val alongM: Double? = null,
    val behind: Boolean = true,
    val acrossM: Double? = 0.0,
    val acrossOther: Boolean = false,
) {
    val x: Double? get() = alongM?.let { if (behind) FieldNotes.HALF_LENGTH + it else FieldNotes.HALF_LENGTH - it }
    val y: Double? get() = acrossM?.let { if (acrossOther) it else -it }
    val isBlank get() = speedDial == null && spinDial == null && feedS == null && elevationDeg == null
}

/** Clip 8, optional: the Hero 7's file of the striped balls. */
data class SpinTruth(
    val clip: String = FieldNotes.SPIN_CLIP, val file: String = "", val balls: Int? = 6,
    /** The machine's setting for the striped balls (clip 8 is fed with topspin): it settles which way the stripe turns. */
    val spin: String = "top",
)

/** The draft on the phone: filesDir/groundtruth/<date>.json, saved on every change. */
class FieldNotesStore(val dir: File) {
    fun file(date: String) = File(dir, "$date.json")

    /** The draft last changed, if any. */
    fun latest(): FieldNotes? = dir.listFiles { f -> f.name.endsWith(".json") }?.maxByOrNull { it.lastModified() }
        ?.let { f -> runCatching { FieldNotes.fromJson(f.readText()) }.getOrNull()?.let { if (it.session.isBlank()) it.copy(session = f.nameWithoutExtension) else it } }

    /** Writes [n] (through a temporary file, so a crash can't leave half a file); a changed date moves the file. */
    fun save(n: FieldNotes, previousDate: String? = null) {
        dir.mkdirs()
        val tmp = File(dir, "${n.session}.json.tmp")
        tmp.writeText(n.toJson())
        val f = file(n.session)
        if (!tmp.renameTo(f)) { f.delete(); tmp.renameTo(f) }
        if (previousDate != null && previousDate != n.session) file(previousDate).delete()
    }
}
