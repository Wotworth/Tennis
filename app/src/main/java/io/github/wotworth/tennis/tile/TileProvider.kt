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
        val withJobs = d.racquets.filter { r -> d.jobs.any { it.racquetId == r.id } }
        if (withJobs.isEmpty()) return TileRow("empty", "", null, null, now)
        val lastPlayed = d.sessions.maxWithOrNull(compareBy<SessionWithRacquets>({ it.session.date }, { it.session.startMillis ?: 0 }, { it.session.id }))?.racquetIds.orEmpty()
        val r = (lastPlayed + lastRacquets + selected).firstNotNullOfOrNull { id -> withJobs.firstOrNull { it.id == id } } ?: withJobs.first()
        val job = Strings.currentJob(r.id, d.jobs)!!
        val hours = Strings.hoursText(Strings.hours(job, d.jobs, d.sessions))
        val small = if (withJobs.size > 1) "hours · ${r.name}" else "hours on these strings"
        return TileRow("hours", hours, small, null, now)
    }
}

/** TIL-01: the read-only provider the launcher's tile reads. */
class TileProvider : ContentProvider() {
    override fun onCreate() = true

    override fun query(uri: Uri, projection: Array<out String>?, selection: String?, selectionArgs: Array<out String>?, sortOrder: String?): Cursor? {
        if (uri.pathSegments != listOf("tile")) return null
        val caller = callingPackage
        if (caller != null && caller !in TileRows.READERS) throw SecurityException("The tennis tile is for the WP launcher only")
        val app = context?.applicationContext as? TennisApp ?: return null
        val row = runBlocking { app.tileRow() }
        return MatrixCursor(TileRows.COLUMNS, 1).apply { addRow(arrayOf<Any?>(row.state, row.big, row.small, row.proposalId, row.updated)) }
    }

    override fun getType(uri: Uri) = "vnd.android.cursor.item/vnd.io.github.wotworth.tennis.tile"
    override fun insert(uri: Uri, values: ContentValues?): Uri? = throw UnsupportedOperationException("read-only")
    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?): Int = throw UnsupportedOperationException("read-only")
    override fun update(uri: Uri, values: ContentValues?, selection: String?, selectionArgs: Array<out String>?): Int = throw UnsupportedOperationException("read-only")
}
