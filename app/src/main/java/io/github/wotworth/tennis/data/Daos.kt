package io.github.wotworth.tennis.data

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Update
import kotlinx.coroutines.flow.Flow

@Dao
interface TennisDao {
    @Query("SELECT * FROM racquets ORDER BY position, id") fun racquets(): Flow<List<Racquet>>
    @Query("SELECT * FROM string_jobs ORDER BY date DESC, id DESC") fun jobs(): Flow<List<StringJob>>
    @Query("SELECT * FROM sessions ORDER BY date DESC, startMillis DESC, id DESC") fun sessions(): Flow<List<Session>>
    @Query("SELECT * FROM session_racquets") fun sessionRacquets(): Flow<List<SessionRacquet>>
    @Query("SELECT * FROM proposals ORDER BY startMillis") fun proposals(): Flow<List<Proposal>>
    @Query("SELECT * FROM cues ORDER BY position, id") fun cues(): Flow<List<Cue>>
    @Query("SELECT * FROM strings ORDER BY brand, model, gauge") fun strings(): Flow<List<StringItem>>

    @Query("SELECT * FROM racquets ORDER BY position, id") suspend fun racquetsNow(): List<Racquet>
    @Query("SELECT * FROM string_jobs ORDER BY date DESC, id DESC") suspend fun jobsNow(): List<StringJob>
    @Query("SELECT * FROM sessions ORDER BY date DESC, id DESC") suspend fun sessionsNow(): List<Session>
    @Query("SELECT * FROM session_racquets") suspend fun sessionRacquetsNow(): List<SessionRacquet>
    @Query("SELECT * FROM proposals ORDER BY startMillis") suspend fun proposalsNow(): List<Proposal>
    @Query("SELECT * FROM cues ORDER BY position, id") suspend fun cuesNow(): List<Cue>
    @Query("SELECT * FROM strings ORDER BY brand, model, gauge") suspend fun stringsNow(): List<StringItem>

    @Insert suspend fun insertRacquet(r: Racquet): Long
    @Update suspend fun updateRacquet(r: Racquet)
    @Delete suspend fun deleteRacquet(r: Racquet)

    @Insert suspend fun insertJob(j: StringJob): Long
    @Update suspend fun updateJob(j: StringJob)
    @Delete suspend fun deleteJob(j: StringJob)

    @Insert suspend fun insertSession(s: Session): Long
    @Update suspend fun updateSession(s: Session)
    @Query("DELETE FROM sessions WHERE id = :id") suspend fun deleteSession(id: Long)
    @Query("DELETE FROM session_racquets WHERE sessionId = :id") suspend fun clearSessionRacquets(id: Long)
    @Insert(onConflict = OnConflictStrategy.IGNORE) suspend fun insertSessionRacquets(rows: List<SessionRacquet>)

    @Insert(onConflict = OnConflictStrategy.IGNORE) suspend fun insertProposal(p: Proposal): Long
    @Query("UPDATE proposals SET state = :state WHERE id = :id") suspend fun setProposalState(id: Long, state: String)
    @Update suspend fun updateProposals(p: List<Proposal>)

    @Insert suspend fun insertCue(c: Cue): Long
    @Update suspend fun updateCues(c: List<Cue>)
    @Delete suspend fun deleteCue(c: Cue)

    @Insert suspend fun insertString(s: StringItem): Long
    @Update suspend fun updateString(s: StringItem)
    @Delete suspend fun deleteString(s: StringItem)

    @Query("DELETE FROM racquets") suspend fun clearRacquets()
    @Query("DELETE FROM sessions") suspend fun clearSessions()
    @Query("DELETE FROM proposals") suspend fun clearProposals()
    @Query("DELETE FROM cues") suspend fun clearCues()
    @Query("DELETE FROM strings") suspend fun clearStrings()
    @Insert suspend fun insertRacquets(r: List<Racquet>)
    @Insert suspend fun insertJobs(j: List<StringJob>)
    @Insert suspend fun insertSessions(s: List<Session>)
    @Insert suspend fun insertProposals(p: List<Proposal>)
    @Insert suspend fun insertCues(c: List<Cue>)
    @Insert suspend fun insertStrings(s: List<StringItem>)
}
