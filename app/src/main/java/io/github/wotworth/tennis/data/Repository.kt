package io.github.wotworth.tennis.data

import androidx.room.withTransaction
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn

/** Everything the screens show, as one value (the data is small: hundreds of rows at most). */
data class AppData(
    val racquets: List<Racquet> = emptyList(),
    val jobs: List<StringJob> = emptyList(),
    val sessions: List<SessionWithRacquets> = emptyList(),
    val proposals: List<Proposal> = emptyList(),
    val cues: List<Cue> = emptyList(),
    val strings: List<StringItem> = emptyList(),
    val loaded: Boolean = false,
) {
    val waiting: List<Proposal> get() = proposals.filter { it.state == "waiting" }
    fun racquet(id: Long) = racquets.firstOrNull { it.id == id }
}

class Repository(private val db: TennisDatabase, scope: CoroutineScope, private val onChange: () -> Unit = {}) {
    val dao = db.dao()

    val data: StateFlow<AppData> = combine(
        combine(dao.racquets(), dao.jobs(), dao.sessions(), dao.sessionRacquets()) { r, j, s, sr ->
            val byId = sr.groupBy({ it.sessionId }, { it.racquetId })
            Triple(r, j, s.map { SessionWithRacquets(it, byId[it.id].orEmpty()) })
        },
        dao.proposals(), dao.cues(), dao.strings(),
    ) { (r, j, s), p, c, st -> AppData(r, j, s, p, c, st, loaded = true) }
        .stateIn(scope, SharingStarted.Eagerly, AppData())

    private suspend fun <T> changed(block: suspend () -> T): T = block().also { onChange() }

    suspend fun saveRacquet(r: Racquet): Long = changed {
        if (r.id == 0L) dao.insertRacquet(r.copy(position = (dao.racquetsNow().maxOfOrNull { it.position } ?: -1) + 1))
        else { dao.updateRacquet(r); r.id }
    }
    suspend fun deleteRacquet(r: Racquet) = changed { dao.deleteRacquet(r) }

    /** STR-04: saving a job also adds its strings to the library. */
    suspend fun saveJob(j: StringJob): Long = changed {
        val id = if (j.id == 0L) dao.insertJob(j) else { dao.updateJob(j); j.id }
        addToLibrary(j.mains, j.mainsPhoto)
        if (j.hybrid) addToLibrary(j.crossesOwn, j.crossesPhoto)
        id
    }
    suspend fun deleteJob(j: StringJob) = changed { dao.deleteJob(j) }

    private suspend fun addToLibrary(spec: StringSpec, photo: String?) {
        if (spec.brand.isBlank() && spec.model.isBlank()) return
        val existing = dao.stringsNow().firstOrNull { same(it.spec, spec) }
        if (existing == null) dao.insertString(StringItem(spec = spec, photo = photo))
        else if (existing.photo == null && photo != null) dao.updateString(existing.copy(photo = photo))
    }

    suspend fun saveString(s: StringItem): Long = changed { if (s.id == 0L) dao.insertString(s) else { dao.updateString(s); s.id } }
    suspend fun deleteString(s: StringItem) = changed { dao.deleteString(s) }

    suspend fun saveSession(s: Session, racquetIds: List<Long>): Long = changed {
        db.runInTransactionSuspend {
            val id = if (s.id == 0L) dao.insertSession(s) else { dao.updateSession(s); s.id }
            dao.clearSessionRacquets(id)
            dao.insertSessionRacquets(racquetIds.distinct().map { SessionRacquet(id, it) })
            id
        }
    }
    suspend fun deleteSession(id: Long) = changed { dao.deleteSession(id) }

    suspend fun addProposal(p: Proposal): Long = changed { dao.insertProposal(p) }
    suspend fun setProposalState(id: Long, state: String) = changed { dao.setProposalState(id, state) }

    suspend fun saveCue(c: Cue): Long = changed {
        if (c.id == 0L) dao.insertCue(c.copy(position = (dao.cuesNow().maxOfOrNull { it.position } ?: -1) + 1))
        else { dao.updateCues(listOf(c)); c.id }
    }
    suspend fun deleteCue(c: Cue) = changed { dao.deleteCue(c) }
    /** CUE-02: store a new order. */
    suspend fun reorderCues(ordered: List<Cue>) = changed { dao.updateCues(ordered.mapIndexed { i, c -> c.copy(position = i) }) }

    /** DAT-02: replace everything (import). */
    suspend fun replaceAll(b: BackupData) = changed {
        db.runInTransactionSuspend {
            dao.clearSessions(); dao.clearRacquets(); dao.clearProposals(); dao.clearCues(); dao.clearStrings()
            dao.insertRacquets(b.racquets); dao.insertJobs(b.jobs); dao.insertSessions(b.sessions)
            dao.insertSessionRacquets(b.sessionRacquets); dao.insertProposals(b.proposals); dao.insertCues(b.cues); dao.insertStrings(b.strings)
        }
    }

    suspend fun snapshot() = BackupData(
        dao.racquetsNow(), dao.jobsNow(), dao.sessionsNow(), dao.sessionRacquetsNow(), dao.proposalsNow(), dao.cuesNow(), dao.stringsNow(),
    )

    companion object {
        fun same(a: StringSpec, b: StringSpec) =
            a.brand.trim().equals(b.brand.trim(), true) && a.model.trim().equals(b.model.trim(), true) && a.gauge.trim().equals(b.gauge.trim(), true)
    }
}

private suspend fun <T> TennisDatabase.runInTransactionSuspend(block: suspend () -> T): T = withTransaction { block() }
