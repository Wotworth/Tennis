package io.github.wotworth.tennis.health

import android.content.Context
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.records.HeartRateRecord as HcHeartRate
import androidx.health.connect.client.records.Record
import androidx.health.connect.client.records.RestingHeartRateRecord
import androidx.health.connect.client.records.StepsRecord as HcSteps
import androidx.health.connect.client.records.metadata.Device
import androidx.health.connect.client.records.metadata.Metadata
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import java.time.LocalDate
import java.time.ZoneId
import kotlin.reflect.KClass

/** DET-01, DET-02: reads one day from Health Connect on the phone. */
class HealthSource(private val context: Context) {

    enum class Availability { Available, NeedsUpdate, Missing }

    fun availability(): Availability = when (HealthConnectClient.getSdkStatus(context)) {
        HealthConnectClient.SDK_AVAILABLE -> Availability.Available
        HealthConnectClient.SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED -> Availability.NeedsUpdate
        else -> Availability.Missing
    }

    private val client by lazy { HealthConnectClient.getOrCreate(context) }

    suspend fun granted(): Set<String> = client.permissionController.getGrantedPermissions()

    suspend fun read(day: LocalDate, zone: ZoneId = ZoneId.systemDefault()): DayData =
        read(day.atStartOfDay(zone).toInstant(), day.plusDays(1).atStartOfDay(zone).toInstant(), zone)

    /** DET-20: any span (the detection's look-back). Resting heart rate is read from a week back. */
    suspend fun read(from: java.time.Instant, to: java.time.Instant, zone: ZoneId = ZoneId.systemDefault()): DayData {
        val day = from.atZone(zone).toLocalDate()
        val range = TimeRangeFilter.between(from, to)
        val restingRange = TimeRangeFilter.between(from.minus(java.time.Duration.ofDays(7)), to)
        val granted = granted()
        suspend fun <T : Record> all(type: KClass<T>, span: TimeRangeFilter? = null): List<T> {
            val range = span ?: range
            if (HealthPermission.getReadPermission(type) !in granted) return emptyList()
            val out = ArrayList<T>()
            var token: String? = null
            do {
                val r = client.readRecords(ReadRecordsRequest(recordType = type, timeRangeFilter = range, pageToken = token))
                out += r.records
                token = r.pageToken
            } while (token != null)
            return out
        }
        return DayData(
            day = day,
            zone = zone,
            heartRate = all(HcHeartRate::class).map { r ->
                HeartRateRecord(r.startTime, r.endTime, r.samples.map { HeartRateSample(it.time, it.beatsPerMinute) }, origin(r.metadata))
            },
            steps = all(HcSteps::class).map { StepsRecord(it.startTime, it.endTime, it.count, origin(it.metadata)) },
            exercise = all(ExerciseSessionRecord::class).map {
                ExerciseRecord(it.startTime, it.endTime, it.exerciseType, ExerciseTypes.name(it.exerciseType), it.title, origin(it.metadata))
            },
            restingHeartRate = all(RestingHeartRateRecord::class, restingRange).map { RestingRecord(it.time, it.beatsPerMinute, origin(it.metadata)) },
        )
    }

    private fun origin(m: Metadata) = Origin(
        packageName = m.dataOrigin.packageName,
        device = m.device?.let { d -> listOfNotNull(d.manufacturer, d.model).joinToString(" ").ifBlank { null } ?: deviceType(d.type) },
        recording = when (m.recordingMethod) {
            Metadata.RECORDING_METHOD_ACTIVELY_RECORDED -> "recorded as a workout"
            Metadata.RECORDING_METHOD_AUTOMATICALLY_RECORDED -> "recorded automatically"
            Metadata.RECORDING_METHOD_MANUAL_ENTRY -> "entered by hand"
            else -> null
        },
    )

    private fun deviceType(t: Int): String? = when (t) {
        Device.TYPE_WATCH -> "watch"
        Device.TYPE_PHONE -> "phone"
        Device.TYPE_FITNESS_BAND -> "fitness band"
        Device.TYPE_RING -> "ring"
        Device.TYPE_CHEST_STRAP -> "chest strap"
        else -> null
    }

    companion object {
        /** DET-02: what the report reads. History lets it read days before access was first given. */
        val permissions: Set<String> = setOf(
            HealthPermission.getReadPermission(HcHeartRate::class),
            HealthPermission.getReadPermission(HcSteps::class),
            HealthPermission.getReadPermission(ExerciseSessionRecord::class),
            HealthPermission.getReadPermission(RestingHeartRateRecord::class),
            HealthPermission.PERMISSION_READ_HEALTH_DATA_HISTORY,
            // DET-20: the hourly check runs in the background.
            HealthPermission.PERMISSION_READ_HEALTH_DATA_IN_BACKGROUND,
        )
        /** What detection needs; history is only for the report. */
        val detectionNeeds: Set<String> = setOf(
            HealthPermission.getReadPermission(HcHeartRate::class),
            HealthPermission.getReadPermission(HcSteps::class),
            HealthPermission.getReadPermission(ExerciseSessionRecord::class),
        )
    }
}

/** Names for the workout types the detection cares about; others show their number. */
object ExerciseTypes {
    fun name(type: Int): String = when (type) {
        ExerciseSessionRecord.EXERCISE_TYPE_TENNIS -> "tennis"
        ExerciseSessionRecord.EXERCISE_TYPE_RACQUETBALL -> "racquetball"
        ExerciseSessionRecord.EXERCISE_TYPE_SQUASH -> "squash"
        ExerciseSessionRecord.EXERCISE_TYPE_BADMINTON -> "badminton"
        ExerciseSessionRecord.EXERCISE_TYPE_TABLE_TENNIS -> "table tennis"
        ExerciseSessionRecord.EXERCISE_TYPE_RUNNING -> "running"
        ExerciseSessionRecord.EXERCISE_TYPE_WALKING -> "walking"
        ExerciseSessionRecord.EXERCISE_TYPE_HIKING -> "hiking"
        ExerciseSessionRecord.EXERCISE_TYPE_BIKING -> "cycling"
        ExerciseSessionRecord.EXERCISE_TYPE_HIGH_INTENSITY_INTERVAL_TRAINING -> "interval training"
        ExerciseSessionRecord.EXERCISE_TYPE_STRENGTH_TRAINING -> "strength training"
        ExerciseSessionRecord.EXERCISE_TYPE_OTHER_WORKOUT -> "other workout"
        else -> "workout type $type"
    }
}
