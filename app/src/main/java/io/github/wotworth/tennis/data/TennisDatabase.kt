package io.github.wotworth.tennis.data

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase

/** DAT-01. Version 1 is the PH-1 schema; every later version needs a tested migration (DAT-04). */
@Database(
    entities = [Racquet::class, StringJob::class, Session::class, SessionRacquet::class, Proposal::class, Cue::class, StringItem::class],
    version = 1,
    exportSchema = true,
)
abstract class TennisDatabase : RoomDatabase() {
    abstract fun dao(): TennisDao

    companion object {
        fun open(context: Context, name: String? = "tennis.db"): TennisDatabase =
            (if (name == null) Room.inMemoryDatabaseBuilder(context, TennisDatabase::class.java)
            else Room.databaseBuilder(context, TennisDatabase::class.java, name)).build()
    }
}
