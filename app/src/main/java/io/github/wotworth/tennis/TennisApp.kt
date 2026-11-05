package io.github.wotworth.tennis

import android.app.Application
import android.os.Build
import io.github.wotworth.tennis.diagnostics.CrashLog
import io.github.wotworth.tennis.health.HealthSource
import io.github.wotworth.tennis.data.Prefs
import io.github.wotworth.tennis.data.Repository
import io.github.wotworth.tennis.data.TennisDatabase
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import java.io.File
import java.time.Instant

/** Holds the app's single instances. */
class TennisApp : Application() {

    lateinit var crashLog: CrashLog
        private set

    val health by lazy { HealthSource(this) }

    val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    val database by lazy { TennisDatabase.open(this) }
    val repo by lazy { Repository(database, scope) { onDataChanged() } }
    val prefs by lazy { Prefs(this) }
    /** PHO-02: package photos, by file name. */
    val photosDir: File get() = File(filesDir, "photos").apply { mkdirs() }

    /** Called after every change to the data; tells the launcher's tile (TIL-02). */
    fun onDataChanged() {
        runCatching { contentResolver.notifyChange(io.github.wotworth.tennis.tile.TileRows.URI, null) }
        dataListeners.forEach { runCatching { it() } }
    }

    /** TIL-01: the tile row, read straight from the database (the provider may start the process). */
    suspend fun tileRow(): io.github.wotworth.tennis.tile.TileRow =
        io.github.wotworth.tennis.tile.TileRows.of(tileData(), prefs.lastRacquets, prefs.selectedRacquet, io.github.wotworth.tennis.domain.Now.millis())

    /** TIL-03 (v0.4): all the tile's faces. */
    suspend fun tileFaces(): List<io.github.wotworth.tennis.tile.TileRow> =
        io.github.wotworth.tennis.tile.TileRows.faces(tileData(), prefs.lastRacquets, prefs.selectedRacquet, io.github.wotworth.tennis.domain.Now.millis(), prefs.tileFlips)

    private suspend fun tileData(): io.github.wotworth.tennis.data.AppData {
        val dao = repo.dao
        val links = dao.sessionRacquetsNow().groupBy({ it.sessionId }, { it.racquetId })
        return io.github.wotworth.tennis.data.AppData(dao.racquetsNow(), dao.jobsNow(), dao.sessionsNow().map { io.github.wotworth.tennis.data.SessionWithRacquets(it, links[it.id].orEmpty()) },
            dao.proposalsNow(), loaded = true)
    }
    val dataListeners = java.util.concurrent.CopyOnWriteArrayList<() -> Unit>()

    val versionText: String
        get() = "${BuildConfig.VERSION_NAME} (${BuildConfig.VERSION_CODE}), built ${BuildConfig.BUILD_DATE}"

    val androidText: String
        get() = "${Build.VERSION.RELEASE} (API ${Build.VERSION.SDK_INT})"

    override fun onCreate() {
        super.onCreate()
        crashLog = CrashLog(File(filesDir, "logs"))
        installCrashHandler()
        // DET-20: the hourly check. (Robolectric tests have no WorkManager.)
        runCatching { io.github.wotworth.tennis.health.DetectionRunner.schedule(this, io.github.wotworth.tennis.health.DetectionPrefs.load(prefs)) }
    }

    /** NFR-02: record every uncaught exception, then let Android handle it as usual. */
    private fun installCrashHandler() {
        val previous = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, throwable ->
            runCatching {
                crashLog.append(
                    crashLog.format(
                        throwable = throwable,
                        threadName = thread.name,
                        appVersion = versionText,
                        androidVersion = androidText,
                        device = "${Build.MANUFACTURER} ${Build.MODEL}",
                        time = Instant.now(),
                    ),
                )
            }
            previous?.uncaughtException(thread, throwable)
        }
    }
}
