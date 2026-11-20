package io.github.wotworth.tennis.vision

import android.content.Context
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import java.util.concurrent.TimeUnit

/**
 * The cloud check in the background (Chris, 22 Nov): every 15 minutes while the cloud is set up, and
 * soon after an answer is given. New sessions and court-corners requests appear in the app and on the
 * live tile; the app posts no notifications (TV-UP-03: the PC's alerts reach the phone through ntfy).
 */
object CloudWork {
    const val PERIODIC = "cloud-check"
    const val SOON = "cloud-send"

    fun schedule(context: Context) {
        val wm = runCatching { WorkManager.getInstance(context) }.getOrNull() ?: return
        if (!CloudConfig.enabled || !CloudTokenStore(context).isSet()) { wm.cancelUniqueWork(PERIODIC); return }
        val req = PeriodicWorkRequestBuilder<CloudWorker>(15, TimeUnit.MINUTES)
            .setConstraints(Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build()).build()
        wm.enqueueUniquePeriodicWork(PERIODIC, ExistingPeriodicWorkPolicy.UPDATE, req)
    }

    fun sendSoon(context: Context) {
        if (!CloudConfig.enabled) return
        val wm = runCatching { WorkManager.getInstance(context) }.getOrNull() ?: return
        wm.enqueueUniqueWork(SOON, ExistingWorkPolicy.REPLACE, OneTimeWorkRequestBuilder<CloudWorker>()
            .setConstraints(Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build()).build())
    }

    /** A sync with the stored passphrase; null when the cloud is not set up. */
    fun sync(context: Context): CloudSync? {
        if (!CloudConfig.enabled) return null
        val token = CloudTokenStore(context).get() ?: return null
        return CloudSync(context, CloudClient(CloudConfig.HOST, token))
    }
}

class CloudWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {
    override suspend fun doWork(): Result = try {
        CloudWork.sync(applicationContext)?.run(); Result.success()
    } catch (e: Exception) {
        android.util.Log.w("Tennis", "cloud check failed: ${e.javaClass.simpleName}"); Result.retry()
    }
}
