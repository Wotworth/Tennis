package io.github.wotworth.tennis.data

import androidx.room.ColumnInfo
import androidx.room.Embedded
import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey

/**
 * The whole schema, defined in PH-1 so later phases need no migration (DAT-04).
 * Dates are local calendar days (epoch day); times are epoch milliseconds.
 * Tensions are stored in pounds and prices in cents (Q7: lb and US dollars).
 */

/** Chris's racquets (v0.3 spec, RAC-01): name, model and colour. */
@Entity(tableName = "racquets")
data class Racquet(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val name: String,
    val model: String = "",
    val colour: String = "",
    val position: Int = 0,
)

/** One string (STR-01): brand, model, gauge, material. */
data class StringSpec(
    val brand: String = "",
    val model: String = "",
    val gauge: String = "",
    val material: String = "",
) {
    val name: String get() = listOf(brand, model).filter { it.isNotBlank() }.joinToString(" ")
    val isBlank: Boolean get() = brand.isBlank() && model.isBlank() && gauge.isBlank() && material.isBlank()
}

/** A string job (STR-01) on one racquet. */
@Entity(
    tableName = "string_jobs",
    foreignKeys = [ForeignKey(entity = Racquet::class, parentColumns = ["id"], childColumns = ["racquetId"], onDelete = ForeignKey.CASCADE)],
    indices = [Index("racquetId")],
)
data class StringJob(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val racquetId: Long,
    val date: Long,
    @Embedded(prefix = "mains_") val mains: StringSpec = StringSpec(),
    val hybrid: Boolean = false,
    @Embedded(prefix = "crosses_") val crossesOwn: StringSpec = StringSpec(),
    val mainsLb: Double? = null,
    val crossesLb: Double? = null,
    val shop: String = "",
    val priceCents: Long? = null,
    val notes: String = "",
    /** PHO-02: file names in the app's photo folder. */
    val mainsPhoto: String? = null,
    val crossesPhoto: String? = null,
) {
    val crosses: StringSpec get() = if (hybrid) crossesOwn else mains
}

/** A session (SES-01, SES-04). Its racquets are in [SessionRacquet]. */
@Entity(tableName = "sessions")
data class Session(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val date: Long,
    val minutes: Int,
    val feel: Int? = null,
    /** "manual", "workout" (DET-10 step 1) or "heart_rate" (step 2). */
    val source: String = "manual",
    val startMillis: Long? = null,
    val endMillis: Long? = null,
    val avgHr: Int? = null,
    val maxHr: Int? = null,
    val steps: Long? = null,
    val notes: String = "",
)

/** Which racquets a session used (v0.3: one or more). */
@Entity(
    tableName = "session_racquets",
    primaryKeys = ["sessionId", "racquetId"],
    foreignKeys = [
        ForeignKey(entity = Session::class, parentColumns = ["id"], childColumns = ["sessionId"], onDelete = ForeignKey.CASCADE),
        ForeignKey(entity = Racquet::class, parentColumns = ["id"], childColumns = ["racquetId"], onDelete = ForeignKey.CASCADE),
    ],
    indices = [Index("racquetId")],
)
data class SessionRacquet(val sessionId: Long, val racquetId: Long)

/** DET-30: a detected window waiting for Yes/No. */
@Entity(tableName = "proposals", indices = [Index(value = ["startMillis", "endMillis"], unique = true)])
data class Proposal(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val startMillis: Long,
    val endMillis: Long,
    val source: String,
    val avgHr: Int? = null,
    val maxHr: Int? = null,
    val steps: Long? = null,
    /** "waiting", "accepted", "rejected" or "expired". */
    val state: String = "waiting",
    val createdMillis: Long = 0,
)

/** CUE-01: a swing cue. */
@Entity(tableName = "cues")
data class Cue(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val heading: String,
    val text: String,
    val pinned: Boolean = false,
    val position: Int = 0,
)

/** STR-30: the string library. */
@Entity(tableName = "strings")
data class StringItem(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    @Embedded val spec: StringSpec,
    val photo: String? = null,
    val notes: String = "",
)

/** A session with its racquets, as the screens use it. */
data class SessionWithRacquets(val session: Session, val racquetIds: List<Long>)
