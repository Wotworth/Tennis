package io.github.wotworth.tennis.tile

import android.content.ContentProvider
import android.content.ContentValues
import android.database.Cursor
import android.database.MatrixCursor
import android.net.Uri
import io.github.wotworth.tennis.TennisApp
import io.github.wotworth.tennis.data.AppData
import io.github.wotworth.tennis.data.Proposal
import io.github.wotworth.tennis.data.SessionWithRacquets
import io.github.wotworth.tennis.domain.Strings
import io.github.wotworth.tennis.ui.screens.windowText
import kotlinx.coroutines.runBlocking

/** TIL-01: what the launcher's tile shows. */
data class TileRow(val state: String, val big: String, val small: String?, val proposalId: String?, val updated: Long)

object TileRows {
    const val AUTHORITY = "io.github.wotworth.tennis.tile"
    val URI: Uri by lazy { Uri.parse("content://$AUTHORITY/tile") }
    /** TIL-03 (v0.4): every face the tile shows, in order; the launcher flips through them. */
    val FACES: Uri by lazy { Uri.parse("content://$AUTHORITY/faces") }
    const val ACTION_OPEN = "io.github.wotworth.tennis.action.OPEN_FROM_TILE"
    val COLUMNS = arrayOf("state", "big", "small", "proposal_id", "updated")

    /** TIL-01: only the launcher (and its preview build) may read the tile; and this app, for tests. */
    val READERS = setOf("io.github.wotworth.wplauncher", "io.github.wotworth.wplauncher.preview", "io.github.wotworth.tennis")

    /**
     * TIL-01: a waiting proposal first (the oldest, "Tennis?" over its window); else the hours on
     * the most recently used racquet's strings (Q11: hours per racquet), with its name when there
     * are several; else empty.
     */
    fun of(d: AppData, lastRacquets: List<Long>, selected: Long, now: Long, window: (Proposal) -> String = { windowText(it) }): TileRow {
        d.waiting.minByOrNull { it.startMillis }?.let { return TileRow("proposal", "Tennis?", window(it), it.id.toString(), now) }
        val withJobs = strung(d)
        val r = lastUsed(d, lastRacquets, selected) ?: return TileRow("empty", "", null, null, now)
        return hoursRow(r, d, withJobs.size > 1, now)
    }

    /** Active racquets with strings logged. */
    private fun strung(d: AppData) = d.active.filter { r -> d.jobs.any { it.racquetId == r.id } }

    /** The racquet in the latest session, else the last chosen, else the one opened last, else the first. */
    fun lastUsed(d: AppData, lastRacquets: List<Long>, selected: Long): io.github.wotworth.tennis.data.Racquet? {
        val withJobs = strung(d)
        val lastPlayed = d.sessions.maxWithOrNull(compareBy<SessionWithRacquets>({ it.session.date }, { it.session.startMillis ?: 0 }, { it.session.id }))?.racquetIds.orEmpty()
        return (lastPlayed + lastRacquets + selected).firstNotNullOfOrNull { id -> withJobs.firstOrNull { it.id == id } } ?: withJobs.firstOrNull()
    }

    private fun hoursRow(r: io.github.wotworth.tennis.data.Racquet, d: AppData, named: Boolean, now: Long): TileRow {
        val job = Strings.currentJob(r.id, d.jobs)!!
        val hours = Strings.hoursText(Strings.hours(job, d.jobs, d.sessions))
        // TIL-01 (v0.6): kept short for the tile. With several racquets the number carries the unit
        // and the racquet's name is the line under it (the launcher cuts it to fit).
        return if (named) TileRow("hours", "$hours h", r.name, null, now) else TileRow("hours", hours, "hours on strings", null, now)
    }

    /**
     * TIL-03 (v0.4): the tile's faces. A waiting proposal is the only face. Otherwise, with
     * [flip] off, the one row of [of]; with it on, one face per active racquet with strings,
     * the last used first, then in the racquets page's order.
     */
    fun faces(d: AppData, lastRacquets: List<Long>, selected: Long, now: Long, flip: Boolean, window: (Proposal) -> String = { windowText(it) }): List<TileRow> {
        val first = of(d, lastRacquets, selected, now, window)
        if (!flip || first.state != "hours") return listOf(first)
        val firstId = lastUsed(d, lastRacquets, selected)?.id
        val ordered = strung(d).sortedBy { if (it.id == firstId) -1 else it.position }
        return ordered.map { hoursRow(it, d, true, now) }
    }
}

/**
 * TIL-05 (v0.7): the tile's state: a waiting session ("proposal", whether the live tile is on or
 * off), else "cues" (the launcher flips through the cues that fit) or "off" (the plain icon).
 */
object TileCues {
    val CUES: Uri by lazy { Uri.parse("content://${TileRows.AUTHORITY}/cues") }
    val BACK: Uri by lazy { Uri.parse("content://${TileRows.AUTHORITY}/back") }

    fun state(d: AppData, liveTile: Boolean, now: Long, window: (Proposal) -> String = { windowText(it) }): TileRow {
        d.waiting.minByOrNull { it.startMillis }?.let { return TileRow("proposal", "Tennis?", window(it), it.id.toString(), now) }
        return TileRow(if (liveTile) "cues" else "off", "", null, null, now)
    }

    /** The cues for the tile: pinned first, in the cues page's order, then the rest. */
    fun cues(d: AppData): List<io.github.wotworth.tennis.data.Cue> =
        d.cues.sortedWith(compareBy({ !it.pinned }, { it.position }, { it.id })).filter { it.text.isNotBlank() }

    /**
     * TIL-05 (v0.8, Chris 7 Nov): no back face; the tile shows only cues (and a found session).
     * `/back` stays for launchers that read it, and answers an empty row, which they treat as no back.
     */
    @Suppress("UNUSED_PARAMETER")
    fun back(d: AppData, today: Long): Pair<String, String> = "" to ""
}

/** TIL-01: the read-only provider the launcher's tile reads. */
class TileProvider : ContentProvider() {
    override fun onCreate() = true

    override fun query(uri: Uri, projection: Array<out String>?, selection: String?, selectionArgs: Array<out String>?, sortOrder: String?): Cursor? {
        val path = uri.pathSegments
        if (path != listOf("tile") && path != listOf("faces") && path != listOf("cues") && path != listOf("back")) return null
        val caller = callingPackage
        if (caller != null && caller !in TileRows.READERS) throw SecurityException("The tennis tile is for the WP launcher only")
        val app = context?.applicationContext as? TennisApp ?: return null
        when (path) {
            listOf("cues") -> return MatrixCursor(arrayOf("text", "heading")).apply { runBlocking { app.tileCues() }.forEach { addRow(arrayOf<Any?>(it.text, it.heading)) } }
            listOf("back") -> return MatrixCursor(arrayOf("big", "small"), 1).apply { val (b, sm) = runBlocking { app.tileBack() }; addRow(arrayOf<Any?>(b, sm)) }
        }
        val rows = runBlocking { if (path == listOf("faces")) app.tileFaces() else listOf(app.tileRow()) }
        return MatrixCursor(TileRows.COLUMNS, rows.size).apply { rows.forEach { row -> addRow(arrayOf<Any?>(row.state, row.big, row.small, row.proposalId, row.updated)) } }
    }

    override fun getType(uri: Uri) = "vnd.android.cursor.item/vnd.io.github.wotworth.tennis.tile"
    override fun insert(uri: Uri, values: ContentValues?): Uri? = throw UnsupportedOperationException("read-only")
    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?): Int = throw UnsupportedOperationException("read-only")
    override fun update(uri: Uri, values: ContentValues?, selection: String?, selectionArgs: Array<out String>?): Int = throw UnsupportedOperationException("read-only")
}
