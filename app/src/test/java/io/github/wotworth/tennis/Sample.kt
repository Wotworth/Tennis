package io.github.wotworth.tennis

import android.os.Looper
import androidx.test.core.app.ApplicationProvider
import io.github.wotworth.tennis.data.Cue
import io.github.wotworth.tennis.data.Proposal
import io.github.wotworth.tennis.data.Racquet
import io.github.wotworth.tennis.data.Session
import io.github.wotworth.tennis.data.StringJob
import io.github.wotworth.tennis.data.StringSpec
import io.github.wotworth.tennis.domain.Now
import kotlinx.coroutines.runBlocking
import org.robolectric.Shadows.shadowOf
import java.time.LocalDate
import java.time.ZoneId

/** Made-up data for screenshots and tests: Chris-like racquets, restrings, sessions and cues. */
object Sample {
    val today: Long = LocalDate.of(2026, 11, 5).toEpochDay()
    fun d(y: Int, m: Int, day: Int) = LocalDate.of(y, m, day).toEpochDay()

    fun app(): TennisApp = ApplicationProvider.getApplicationContext()

    /** Waits (on the test thread) until the repository has published [ready]. */
    fun waitFor(app: TennisApp, ready: (io.github.wotworth.tennis.data.AppData) -> Boolean) {
        val until = System.currentTimeMillis() + 10_000
        while (!ready(app.repo.data.value)) {
            shadowOf(Looper.getMainLooper()).idle()
            check(System.currentTimeMillis() < until) { "data never arrived" }
            Thread.sleep(10)
        }
    }

    fun empty(): TennisApp = app().also { Now.fixedDay = today; waitFor(it) { d -> d.loaded } }

    fun fill(app: TennisApp = app(), proposals: Boolean = false, layout: Int = 1): TennisApp {
        Now.fixedDay = today
        Now.fixedMillis = LocalDate.of(2026, 11, 5).atTime(19, 0).atZone(ZoneId.systemDefault()).toInstant().toEpochMilli()
        runBlocking {
            val r = app.repo
            val bb1 = r.saveRacquet(Racquet(name = "Black Blade #1", model = "Wilson Blade 98 v9", colour = "black"))
            val bb2 = r.saveRacquet(Racquet(name = "Black Blade #2", model = "Wilson Blade 98 v9", colour = "black"))
            r.saveRacquet(Racquet(name = "Pure Aero", model = "Babolat Pure Aero 2023", colour = "blue"))
            val hyper = StringSpec("Solinco", "Hyper-G", "16L", "co-poly")
            val alu = StringSpec("Luxilon", "Alu Power", "125", "co-poly")
            r.saveJob(StringJob(racquetId = bb1, date = d(2026, 9, 1), mains = hyper, mainsLb = 54.0, crossesLb = 54.0, shop = "Racquet Lab", priceCents = 3500))
            r.saveJob(StringJob(racquetId = bb1, date = d(2026, 10, 12), mains = hyper, hybrid = true, crossesOwn = alu, mainsLb = 55.0, crossesLb = 53.0, shop = "Racquet Lab", priceCents = 3850))
            r.saveJob(StringJob(racquetId = bb2, date = d(2026, 10, 20), mains = StringSpec("Babolat", "RPM Blast", "17", "co-poly"), mainsLb = 52.0, crossesLb = 52.0, shop = "Racquet Lab", priceCents = 3600))
            listOf(
                Triple(d(2026, 10, 13), 90, 5), Triple(d(2026, 10, 16), 120, 5), Triple(d(2026, 10, 19), 90, 4),
                Triple(d(2026, 10, 23), 120, 4), Triple(d(2026, 10, 27), 90, 4), Triple(d(2026, 10, 30), 120, 3), Triple(d(2026, 11, 3), 90, 3),
            ).forEach { (day, min, feel) -> r.saveSession(Session(date = day, minutes = min, feel = feel), listOf(bb1)) }
            r.saveSession(Session(date = d(2026, 11, 4), minutes = 120, feel = 3, source = "heart_rate", avgHr = 132, maxHr = 167, steps = 6200), listOf(bb1, bb2))
            r.saveCue(Cue(heading = "forehand", text = "Keep the racket face flat on the backswing.", pinned = true))
            r.saveCue(Cue(heading = "serve", text = "Toss up and a little in front. Reach up to it.", pinned = true))
            r.saveCue(Cue(heading = "backhand", text = "Turn the shoulders early.", pinned = true))
            r.saveCue(Cue(heading = "footwork", text = "Split step as they hit."))
            r.saveCue(Cue(heading = "mental", text = "Breathe out on contact."))
            if (proposals) {
                val start = LocalDate.of(2026, 11, 5).atTime(17, 10).atZone(ZoneId.systemDefault()).toInstant().toEpochMilli()
                r.addProposal(Proposal(startMillis = start, endMillis = start + 85 * 60_000, source = "heart_rate", avgHr = 134, maxHr = 166, steps = 5900))
            }
            app.prefs.selectRacquet(bb1)
            app.prefs.chooseStringsLayout(layout)
        }
        waitFor(app) { it.cues.size == 5 && it.sessions.size == 8 && (!proposals || it.proposals.isNotEmpty()) }
        return app
    }
}
