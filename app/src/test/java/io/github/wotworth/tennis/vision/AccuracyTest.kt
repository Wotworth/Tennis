package io.github.wotworth.tennis.vision

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/** Item 14: reading the accuracy report's numbers, with any test missing. */
class AccuracyTest {
    private val example = """{"session":"2026-11-25","synthetic":false,
 "cameras":[{"cam":1,"found":[-14.4,-9.5,3.5],"taped":[-14.39,-9.49,3.5],"errCm":2.1}],
 "drop":{"n":9,"g":9.79,"gSpread":0.08,"gTruth":9.81,"heightM":2.031,"heightSpreadM":0.006,"heightTruthM":2.0335},
 "still":[{"name":"near T","found":true,"errCm":1.4,"gapCm":0.8}],
 "targets":[{"name":"far left corner","n":6,"medianCm":3.2,"worstCm":7.9}],
 "machine":[{"setting":"medium flat","n":10,"speedMph":44.7,"speedSdMph":0.6,"spinFt":1.0,"spinSdFt":0.1,"landSdCm":21}],
 "spin":{"medianDiffRpm":50,"rows":[{"ball":1,"stripeRpm":2050,"stripeSdRpm":20,"systemRpm":2000,"systemSdRpm":100,"inside":true}]}}"""

    @Test fun readsEverySection() {
        val r = AccuracyJson.read(example)
        assertEquals("2026-11-25", r.session)
        assertFalse(r.synthetic)
        assertEquals(listOf(-14.4, -9.5, 3.5), r.cameras[0].found)
        assertEquals(2.1, r.cameras[0].errCm!!, 1e-9)
        assertEquals(9.79, r.drop!!.g!!, 1e-9)
        assertEquals(2.0335, r.drop!!.heightTruthM!!, 1e-9)
        assertTrue(r.still[0].found)
        assertEquals(6, r.targets[0].n)
        assertEquals(21.0, r.machine[0].landSdCm!!, 1e-9)
        assertEquals(50.0, r.spin!!.medianDiffRpm!!, 1e-9)
        assertEquals(true, r.spin!!.rows[0].inside)
    }

    @Test fun testsNotDoneAreEmptyOrMissing() {
        val r = AccuracyJson.read("""{"session":"2026-11-25","synthetic":false,"cameras":[],"drop":[],"still":[],"targets":[],"machine":[],"spin":[]}""")
        assertTrue(r.cameras.isEmpty() && r.still.isEmpty() && r.targets.isEmpty() && r.machine.isEmpty())
        assertNull(r.drop); assertNull(r.spin)
        val bare = AccuracyJson.read("""{"session":"2026-11-25"}""")
        assertNull(bare.drop); assertNull(bare.spin); assertFalse(bare.synthetic)
        assertTrue(bare.machine.isEmpty())
    }

    @Test fun matlabLoneObjectsAndNulls() {
        // jsonencode writes a one-element struct array as an object, and NaN as null
        val r = AccuracyJson.read("""{"session":"2026-11-25","still":{"name":"net tape","found":false,"errCm":null,"gapCm":null},
            "machine":{"setting":"slow slice","n":9,"speedMph":31.2,"speedSdMph":null,"spinFt":-1.9,"spinSdFt":0.2,"landSdCm":33},
            "spin":{"medianDiffRpm":null,"rows":{"ball":1,"stripeRpm":2050,"stripeSdRpm":20,"systemRpm":2000,"systemSdRpm":100,"inside":false}}}""")
        assertEquals(1, r.still.size); assertFalse(r.still[0].found); assertNull(r.still[0].errCm)
        assertEquals(1, r.machine.size); assertNull(r.machine[0].speedSdMph)
        assertEquals(1, r.spin!!.rows.size); assertEquals(false, r.spin!!.rows[0].inside)
    }

    @Test fun bundledSampleIsSyntheticAndComplete() {
        val r = AccuracyJson.read(File("src/main/assets/vision/accuracy/sample.json").readText())
        assertTrue(r.synthetic)
        assertTrue(r.cameras.isNotEmpty() && r.still.isNotEmpty() && r.targets.isNotEmpty() && r.machine.isNotEmpty())
        assertTrue(r.drop != null && r.spin != null && r.spin!!.rows.isNotEmpty())
    }

    @Test fun newestFirstRealBeforeSample() {
        val base = AccuracyJson.read(example)
        val list = listOf(base.copy(session = "2026-11-24", synthetic = true), base.copy(session = "2026-12-01"), base.copy(session = "2026-11-24"))
        assertEquals(listOf("2026-12-01" to false, "2026-11-24" to false, "2026-11-24" to true), AccuracyJson.newestFirst(list).map { it.session to it.synthetic })
    }
}
