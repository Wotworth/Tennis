package io.github.wotworth.tennis.vision

import androidx.test.ext.junit.runners.AndroidJUnit4
import io.github.wotworth.tennis.ui.screens.Court
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File
import kotlin.math.abs

/**
 * Chris, 19 Nov: the sample session's shot 29·1 was drawn going through the net while its card said
 * it cleared the net by 17 in and landed in. Each sample shot's drawn path and its shown numbers
 * must be one flight: the path crosses the net at the clearance shown, an "in" or "out" shot's path
 * is over the tape, and a "net" shot's path ends on the net under the tape.
 */
@RunWith(AndroidJUnit4::class)
class SamplePathsTest {
    private val ballRadius = 0.0335

    private fun sample(): VisionSession {
        fun read(n: String) = File("src/main/assets/vision/sample/$n").readText()
        return VisionJson.session("sample", read("session.json"), read("shots.json"), read("rallies.json"), read("trajectories.json"), sample = true)
    }

    /** Height of the ball's underside where the path crosses the net (x = 0), or null if it never does. */
    private fun undersideAtNet(xyz: List<DoubleArray>): Double? {
        for (i in 0 until xyz.size - 1) {
            val a = xyz[i]; val b = xyz[i + 1]
            if (a[0] * b[0] <= 0 && a[0] != b[0]) {
                val f = a[0] / (a[0] - b[0])
                return a[2] + f * (b[2] - a[2]) - ballRadius
            }
        }
        return null
    }

    @Test fun everyDrawnPathAgreesWithTheNumbersOnItsCard() {
        val v = sample()
        var over = 0; var nets = 0
        for (s in v.shots) {
            val tr = v.trajectory(s.rally, s.index) ?: continue
            val name = "shot ${s.rally}·${s.index}"
            if (s.call == "net") {
                nets++
                val end = tr.xyz.last()
                assertTrue("$name is a net ball but its path does not end on the net", abs(end[0]) < 0.05)
                assertTrue("$name is a net ball but its path ends over the tape", end[2] - ballRadius < Court.NET_CENTRE)
                assertTrue("$name is a net ball but its clearance is not negative", (s.netClearance ?: 0.0) < 0.0)
                continue
            }
            val z = undersideAtNet(tr.xyz) ?: continue
            over++
            assertTrue("$name is called ${s.call} but its path is ${"%.2f".format(Court.NET_CENTRE - z)} m under the tape", z >= Court.NET_CENTRE)
            assertEquals("$name: the path at the net against the clearance shown", s.netClearance!!, z - Court.NET_CENTRE, 0.03)
        }
        assertTrue("the sample should have shots over the net and into it ($over, $nets)", over > 100 && nets > 5)
    }
}
