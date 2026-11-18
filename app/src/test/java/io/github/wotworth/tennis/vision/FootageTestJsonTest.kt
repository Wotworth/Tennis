package io.github.wotworth.tennis.vision

import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import org.junit.runner.RunWith

/** Footage tests (Chris, 17 Nov): reading tv.out.singleTest's test.json, shaped like MATLAB's jsonencode. */
@RunWith(AndroidJUnit4::class)
class FootageTestJsonTest {
    // made-up numbers; a lone clip, bounce and frame come out as objects, a lone corner as a string
    private val json = """{"id":"t","title":"made-up match","date":"1 Jan","source":"phone",
        "video":{"lengthS":61.5,"fps":60,"width":1920,"height":1080},
        "court":{"image":"court.jpg","imageWidth":960,"imageHeight":540,"lines":[[[10,500],[300,200]],[[20,510],[900,520]]],
          "net":[[100,150],[800,160]],"hfovDeg":64.3,"camera":[-18.0,0.1,3.2],"lineRmsPx":1.03,"paintShare":0.96,
          "cornersOutOfView":"near right singles","scorecard":{"medianPx":20,"perPointPx":[47,15,25]}},
        "clips":{"index":1,"startS":0,"lengthS":10.5,"frames":630,"framesWithBall":400,"tracks":7,"bounces":3},
        "ball":{"framesInClips":630,"framesWithBall":400,"candidates":2000,"tracks":7,"check":null},
        "bounces":{"clip":1,"t":3.25,"x":5.1,"y":-2.0,"call":"in","marginM":2.1},
        "players":{"samples":20,"withTwoOnCourt":17,"withOneOrMore":20},
        "frames":{"file":"f_01.jpg","clip":1,"t":4.0,"verdict":"found","caption":"serve"},
        "notes":"one note"}"""

    @Test fun readsTheTestFile() {
        val t = FootageTestJson.read("t", json)
        assertEquals(1, t.clips.size)
        assertEquals(400, t.clips[0].framesWithBall)
        assertEquals(2, t.court.lines.size)
        assertEquals(listOf("near right singles"), t.court.cornersOutOfView)
        assertEquals(20.0, t.court.scorecardMedianPx!!, 1e-9)
        assertEquals(1, t.bounces.size)
        assertEquals("in", t.bounces[0].call)
        assertEquals(1, t.frames.size)
        assertNull(t.ball.check)
        assertEquals(listOf("one note"), t.notes)
    }
}

/** Chris, 17 Nov: only the clay test ships (the two earlier iPhone tests were temporary). */
@RunWith(AndroidJUnit4::class)
class FootageTestAssetsTest {
    private val context = androidx.test.core.app.ApplicationProvider.getApplicationContext<android.content.Context>()

    @Test fun onlyTheClayTestShips() {
        assertEquals(listOf("iphone-2025-11-10-clay"), FootageTests(context).all.map { it.id })
        assertEquals("10 Nov 2025", FootageTests(context).all.single().date)
    }
}
