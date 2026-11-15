package io.github.wotworth.tennis.vision

import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

/** TV-APP-01 to 05 and TV-HC-02, 03: reading the PC's files, units, heart rate on the phone. */
@RunWith(AndroidJUnit4::class)
class VisionTest {

    // Shaped like MATLAB's jsonencode output: NaN becomes null, a lone struct is an object.
    private val session = """{"startUtc":"2026-11-14T15:00:00.000Z","air":{"rho":1.19,"wind":[0.6,-0.3],"sessionCD":0.51},
        "crossing":{"minDeg":41.2,"thresholdDeg":20,"low":[],"text":"fine"},"identity":{"question":true}}"""
    private val shots = """[{"rally":1,"index":1,"t":2.3,"hitter":"Chris","type":"serve","isServe":true,"speedContact":42.0,
        "contact":[-11.9,-0.7,2.75],"bounce":[5.0,2.3],"bounceSd":0.02,"call":"in","spinEffect":-1.2,"rpm":null,"rpmSd":null,
        "spinLabel":"flat / low spin","netClearance":0.12},
        {"rally":1,"index":2,"t":3.1,"hitter":"Player A","type":"groundstroke","isServe":false,"speedContact":25.0,
        "contact":[11.9,2.8,0.9],"bounce":[null,null],"call":"net","spinEffect":null,"rpm":2100,"rpmSd":525,"spinLabel":"topspin"}]"""
    private val rallies = """{"index":1,"start":0.8,"stop":10.9,"shots":2,"duration":5.3,"ending":"net","fastest":42.0}"""
    private val trajectories = """[{"rally":1,"shot":1,"t0":2.3,"dt":0.005,"xyz":[[-11.9,-0.7,2.75],[-11.7,-0.68,2.74]],"noSpin":[1,2,3]}]"""

    @Test fun readsThePcFiles() {
        val v = VisionJson.session("s", session, shots, rallies, trajectories, sample = false)
        assertEquals(2, v.shots.size)
        assertEquals(1, v.rallies.size)                           // a lone object, not an array
        assertEquals(42.0, v.shots[0].speedContact!!, 1e-9)
        assertNull(v.shots[0].rpm)                                // null from NaN
        assertNull(v.shots[1].bounce)                             // [null, null]: no bounce
        assertEquals(listOf(5.0, 2.3), v.shots[0].bounce)
        assertEquals(2, v.trajectory(1, 1)!!.xyz.size)
        assertEquals(1, v.trajectory(1, 1)!!.noSpin.size)         // a one-row matrix comes out flat
        assertTrue(v.identityQuestion)
        assertEquals(41.2, v.crossing!!.minDeg, 1e-9)
        assertEquals(0.51, v.sessionCD!!, 1e-9)
    }

    @Test fun showsMphFeetAndRpm() {
        assertEquals("94 mph", Units.mph(42.0))
        assertEquals("3.9 ft", Units.ft(1.2))
        assertEquals("-12 ft", Units.ft(-3.8))
        assertEquals("5 in", Units.inches(0.12))
        assertEquals("2100 rpm ± 530", Units.rpm(2100.0, 525.0))
        assertEquals("–", Units.mph(null))
    }

    @Test fun heartRateZonesAndRallies() {
        // 160 bpm in rallies (0-60 s), 120 bpm between (60-120 s), every 2 s; max 190
        val s = (0 until 60).map { HrSample(it * 2.0, if (it < 30) 160 else 120) }
        val h = HeartRate.summary(s, listOf(0.0 to 59.0), maxHr = 190)
        assertEquals(160, h.inRallies)
        assertEquals(120, h.between)
        assertEquals(160, h.max)
        assertEquals(60.0, h.zoneSeconds[3], 1e-9)                // 160/190 = 84%: zone 80-90
        assertEquals(59.0, h.zoneSeconds[1], 1e-9)                // 120/190 = 63%: zone 60-70 (the last sample counts 1 s)
        assertTrue(h.gaps.isEmpty())
    }

    @Test fun gapsOverAMinuteAreNotFilledIn() {
        val s = listOf(HrSample(0.0, 150), HrSample(5.0, 150), HrSample(200.0, 150), HrSample(205.0, 150))
        val h = HeartRate.summary(s, emptyList(), maxHr = 190)
        assertEquals(1, h.gaps.size)
        assertEquals(5.0 + 60.0 + 5.0 + 1.0, h.coveredS, 1e-9)   // the gap counts only up to a minute
    }

    @Test fun noHeartRateMeansNoSummary() {
        assertNull(HeartRate.summary(emptyList(), emptyList(), 190).avg)
    }
}
