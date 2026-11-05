package io.github.wotworth.tennis.health

import android.content.Context
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import io.github.wotworth.tennis.TennisApp
import io.github.wotworth.tennis.data.Prefs
import io.github.wotworth.tennis.domain.Busy
import io.github.wotworth.tennis.domain.Detection
import io.github.wotworth.tennis.domain.DetectionSettings
import io.github.wotworth.tennis.domain.Now
import java.time.Instant
import java.time.ZoneId
import java.util.concurrent.TimeUnit

/** DET-11: the detection settings, kept in [Prefs]. */
object DetectionPrefs {
    fun load(p: Prefs): DetectionSettings {
        val d = DetectionSettings()
        return DetectionSettings(
            minMinutes = p.getInt("det.minMinutes", d.minMinutes),
            rollingMinutes = p.getInt("det.rollingMinutes", d.rollingMinutes),
            maxGapMinutes = p.getInt("det.maxGapMinutes", d.maxGapMinutes),
            reserveShare = p.getFloat("det.reserveShare", d.reserveShare.toFloat()).toDouble(),
            birthYear = p.getInt("det.birthYear", d.birthYear),
            restingFallback = p.getInt("det.restingFallback", d.restingFallback),
            otherRacquetSports = p.getInt("det.otherRacquet", 0) == 1,
            lookbackHours = p.getInt("det.lookbackHours", d.lookbackHours),
            checkEveryMinutes = p.getInt("det.checkEvery", d.checkEveryMinutes),
            expiryDays = p.getInt("det.expiryDays", d.expiryDays),
            enabled = p.getInt("det.enabled", 1) == 1,
        )
    }

    fun save(p: Prefs, s: DetectionSettings) {
        p.putInt("det.minMinutes", s.minMinutes); p.putInt("det.rollingMinutes", s.rollingMinutes); p.putInt("det.maxGapMinutes", s.maxGapMinutes)
        p.putFloat("det.reserveShare", s.reserveShare.toFloat()); p.putInt("det.birthYear", s.birthYear); p.putInt("det.restingFallback", s.restingFallback)
        p.putInt("det.otherRacquet", if (s.otherRacquetSports) 1 else 0); p.putInt("det.lookbackHours", s.lookbackHours)
        p.putInt("det.checkEvery", s.checkEveryMinutes); p.putInt("det.expiryDays", s.expiryDays); p.putInt("det.enabled", if (s.enabled) 1 else 0)
    }
}

/** DET-20: one detection run, from the hourly check or when the app opens. */
object DetectionRunner {

    data class Result(val ran: Boolean, val message: String, val newCount: Int = 0)

    suspend fun run(app: TennisApp): Result {
        val s = DetectionPrefs.load(app.prefs)
        if (!s.enabled) return Result(false, "off")
        val health = app.health
        if (health.availability() != HealthSource.Availability.Available) return Result(false, "Health Connect isn't available")
        val granted = health.granted()
        if (!granted.containsAll(HealthSource.detectionNeeds)) return Result(false, "Health Connect access not given")
        val now = Now.millis()
        val zone = ZoneId.systemDefault()
        val data = health.read(Instant.ofEpochMilli(now - s.lookbackHours * 3_600_000L), Instant.ofEpochMilli(now), zone)
        val year = Instant.ofEpochMilli(now).atZone(zone).year
        val d = app.repo.data.value.takeIf { it.loaded } ?: run {
            // Worker start: the repository may not have loaded yet.
            val dao = app.repo.dao
            io.github.wotworth.tennis.data.AppData(sessions = dao.sessionsNow().map { io.github.wotworth.tennis.data.SessionWithRacquets(it, emptyList()) }, proposals = dao.proposalsNow(), loaded = true)
        }
        val busy = d.sessions.map { Busy(it.session.date, it.session.startMillis, it.session.endMillis) }
        val cands = Detection.filter(Detection.detect(data, s, year), busy) { Instant.ofEpochMilli(it).atZone(zone).toLocalDate().toEpochDay() }
        val n = app.repo.applyMerge(Detection.merge(cands, app.repo.dao.proposalsNow(), s, now))
        app.prefs.putLong("det.lastRun", now)
        return Result(true, "checked", n)
    }

    const val WORK = "detect-sessions"

    /** DET-20: the periodic check (Android runs it at most every 15 min; default every 60). */
    fun schedule(context: Context, s: DetectionSettings) {
        val wm = WorkManager.getInstance(context)
        if (!s.enabled) { wm.cancelUniqueWork(WORK); return }
        val req = PeriodicWorkRequestBuilder<DetectionWorker>(s.checkEveryMinutes.coerceAtLeast(15).toLong(), TimeUnit.MINUTES)
            .setConstraints(Constraints.Builder().setRequiresBatteryNotLow(true).build())
            .build()
        wm.enqueueUniquePeriodicWork(WORK, ExistingPeriodicWorkPolicy.UPDATE, req)
    }
}

/** DET-20: runs [DetectionRunner] in the background. Never posts a notification (SCP-20). */
class DetectionWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {
    override suspend fun doWork(): Result {
        val app = applicationContext as TennisApp
        return try { DetectionRunner.run(app); Result.success() } catch (e: Exception) {
            android.util.Log.w("Tennis", "detection failed", e); Result.success()
        }
    }
}
