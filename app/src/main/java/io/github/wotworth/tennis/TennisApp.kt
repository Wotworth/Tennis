package io.github.wotworth.tennis

import android.app.Application
import android.os.Build
import io.github.wotworth.tennis.diagnostics.CrashLog
import io.github.wotworth.tennis.health.HealthSource
import java.io.File
import java.time.Instant

/** Holds the app's single instances. */
class TennisApp : Application() {

    lateinit var crashLog: CrashLog
        private set

    val health by lazy { HealthSource(this) }

    val versionText: String
        get() = "${BuildConfig.VERSION_NAME} (${BuildConfig.VERSION_CODE}), built ${BuildConfig.BUILD_DATE}"

    val androidText: String
        get() = "${Build.VERSION.RELEASE} (API ${Build.VERSION.SDK_INT})"

    override fun onCreate() {
        super.onCreate()
        crashLog = CrashLog(File(filesDir, "logs"))
        installCrashHandler()
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
