package io.github.wotworth.tennis.vision

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/** Item 9: the field notes file has the template's keys and nesting, and the template's positions. */
class FieldNotesTest {
    // unit tests run in app/; the template is at the repository's root
    private val templateFile = File("../vision/groundtruth/template.json")
    private val template by lazy { MiniJson.parse(templateFile.readText()).obj()!! }

    /** Keys and nesting only: an object's key set, an array's element shape, every plain value alike. */
    private fun shape(v: Any?): Any = when (v) {
        is Map<*, *> -> v.entries.associate { it.key.toString() to shape(it.value) }.toSortedMap()
        is List<*> -> v.map { shape(it) }.distinct().let { require(it.size <= 1) { "elements differ: $it" }; listOf(it.firstOrNull() ?: "empty") }
        else -> "value"
    }

    private fun full() = FieldNotes("2026-11-24").withSpin(true)

    @Test fun templateIsWhereTheTestLooks() = assertTrue(templateFile.absolutePath, templateFile.isFile)

    @Test fun sameKeysAndNestingAsTheTemplate() {
        val ours = MiniJson.parse(full().toJson())
        assertEquals(shape(template), shape(ours))
        // without the optional spin clip, the same less spinTruth
        val noSpin = MiniJson.parse(FieldNotes("2026-11-24").toJson()).obj()!!
        assertFalse("spinTruth" in noSpin)
        assertEquals(shape(template - "spinTruth"), shape(noSpin))
    }

    @Test fun targetPositionsMatchTheTemplate() {
        val ours = FieldNotes("2026-11-24").targets.spots.associateBy { it.name }
        val spots = template["targets"].obj()!!["spots"].objs()
        assertTrue(spots.isNotEmpty())
        for (s in spots) {
            val t = ours[s.text("name")] ?: error("no default target named ${s.text("name")}")
            assertEquals(s.num("fromBaselineM")!!, t.fromBaselineM!!, 1e-9)
            assertEquals(s.num("fromSidelineM")!!, t.fromSidelineM!!, 1e-9)
            assertEquals("${s.text("name")} x", s.num("x")!!, t.x!!, 1e-9)
            assertEquals("${s.text("name")} y", s.num("y")!!, t.y!!, 1e-9)
        }
    }

    @Test fun theSixTargetsOfTheManual() {
        val t = FieldNotes("2026-11-24").targets.spots
        assertEquals(6, t.size)
        val centre = t.filter { it.side == TargetSide.CENTRE }
        assertEquals(listOf(10.885, 5.9), centre.map { Math.round(it.x!! * 1e4) / 1e4 })
        assertTrue(centre.all { it.y == 0.0 && it.fromSidelineM == null })
        val boxes = t.filter { "service box" in it.name }
        assertEquals(listOf(-2.0575, 2.0575), boxes.map { Math.round(it.y!! * 1e4) / 1e4 })
        assertTrue(boxes.all { Math.abs(it.x!! - 3.2) < 1e-9 })
    }

    @Test fun stillBallsAndDropsMatchTheTemplate() {
        val json = MiniJson.parse(full().toJson()).obj()!!
        for (k in listOf("stillBalls", "drops")) {
            val a = template[k].obj()!!; val b = json[k].obj()!!
            val listKey = if (k == "stillBalls") "balls" else "spots"
            val ta = a[listKey].objs(); val tb = b[listKey].objs()
            assertEquals(ta.map { it.text("name") }, tb.map { it.text("name") })
            ta.zip(tb).forEach { (x, y) -> for (c in listOf("x", "y", "z", "count")) assertEquals("$k ${x.text("name")} $c", x.num(c), y.num(c)) }
        }
        assertEquals(template["drops"].obj()!!.num("releaseHeightM"), json["drops"].obj()!!.num("releaseHeightM"))
        // the net-tape ball off when it wouldn't balance
        val five = FieldNotes("x").copy(still = NoteStill(netTape = false)).still.balls
        assertEquals(5, five.size)
        assertTrue(five.none { it.name == FieldNotes.NET_TAPE })
    }

    @Test fun machinePlaceAndCameras() {
        val c = MachineClip("clip4", "medium flat", alongM = 0.415, behind = true, acrossM = 0.0)
        assertEquals(12.3, c.x!!, 1e-9)
        assertEquals(0.0, c.y!!, 1e-9)
        assertEquals(11.385, c.copy(behind = false, alongM = 0.5).x!!, 1e-9)
        assertEquals(-1.0, c.copy(acrossM = 1.0).y!!, 1e-9)
        assertEquals(1.0, c.copy(acrossM = 1.0, acrossOther = true).y!!, 1e-9)
        assertEquals(listOf("near", "far"), FieldNotes("x").cameras.map { it.atEnd })
    }

    @Test fun readsBackWhatItWrites() {
        val n = full().copy(
            chrisNote = "Linear offered; shutter 1/1920",
            cameras = listOf(NoteCamera(1, 3.5, 4.0, 2.5, "near"), NoteCamera(2, 3.45, 4.1, 2.55, "far")),
            court = NoteCourt(0.08, 0.05, 10.97),
            still = NoteStill(atS = 40.0, netTape = false),
            targets = NoteTargets(spots = NoteTargets.DEFAULTS.take(3) + Target("extra", TargetSide.OTHER, 2.0, 1.0)),
            machine = listOf(MachineClip("clip4", "medium flat", 5.0, 0.0, 4.0, 10.0, 0.415, true, 0.3, true)),
            spin = SpinTruth(file = "HERO7/GH010001.MP4", balls = 6),
        )
        val back = FieldNotes.fromJson(n.toJson())
        assertEquals(n, back)
    }

    @Test fun readsTheTemplate() {
        val n = FieldNotes.fromJson(templateFile.readText())
        assertEquals("2026-11-24", n.session)
        assertEquals("", n.chrisNote)
        assertEquals(3.5, n.cameras[0].heightM!!, 1e-9)
        assertEquals(2, n.targets.spots.size)
        assertEquals(TargetSide.OTHER, n.targets.spots[1].side)
        assertEquals(12.3, n.machine[0].x!!, 1e-9)
        assertNotNull(n.spin)
        assertTrue(n.still.netTape)
    }

    @Test fun draftSavesAndComesBack() {
        val dir = File(System.getProperty("java.io.tmpdir"), "fieldnotes-${System.nanoTime()}")
        try {
            val s = FieldNotesStore(dir)
            assertNull(s.latest())
            val a = FieldNotes("2026-11-23").copy(court = NoteCourt(0.08, null, null))
            s.save(a)
            assertEquals(a, s.latest())
            // a changed date moves the file
            s.save(a.copy(session = "2026-11-24"), previousDate = "2026-11-23")
            assertFalse(s.file("2026-11-23").exists())
            assertEquals("2026-11-24", s.latest()!!.session)
        } finally { dir.deleteRecursively() }
    }

    @Test fun jsonNumbersAndTextAreClean() {
        val j = full().toJson()
        assertFalse(j, Regex("""\d\.\d{5,}""").containsMatchIn(j))   // no 11.765000000000001
        assertTrue(j.contains("\"x\": -11.765"))
        assertEquals("a \"b\"\nc", MiniJson.parse(MiniJson.write("a \"b\"\nc")))
    }
}
