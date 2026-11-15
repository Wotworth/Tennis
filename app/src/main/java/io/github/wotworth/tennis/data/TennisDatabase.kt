package io.github.wotworth.tennis.data

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase
import androidx.room.migration.Migration
import androidx.sqlite.db.SupportSQLiteDatabase

/** DAT-01. Version 1 is the PH-1 schema; 2 adds retired racquets (v0.4); 3 adds Tennis Vision courts and session labels. Every version has a tested migration (DAT-04). */
@Database(
    entities = [Racquet::class, StringJob::class, Session::class, SessionRacquet::class, Proposal::class, Cue::class, StringItem::class, Court::class, VisionLabel::class],
    version = 3,
    exportSchema = true,
)
abstract class TennisDatabase : RoomDatabase() {
    abstract fun dao(): TennisDao

    companion object {
        fun open(context: Context, name: String? = "tennis.db"): TennisDatabase =
            (if (name == null) Room.inMemoryDatabaseBuilder(context, TennisDatabase::class.java)
            else Room.databaseBuilder(context, TennisDatabase::class.java, name)).addMigrations(MIGRATION_1_2, MIGRATION_2_3).build()

        /**
         * v0.4 (Chris, 6 Nov): racquets can be retired; a session has one racquet. A session that
         * had two keeps the one chosen first (lowest row id). Nothing else changes.
         */
        val MIGRATION_1_2 = object : Migration(1, 2) {
            override fun migrate(db: SupportSQLiteDatabase) {
                db.execSQL("ALTER TABLE racquets ADD COLUMN retired INTEGER NOT NULL DEFAULT 0")
                db.execSQL("DELETE FROM session_racquets WHERE rowid NOT IN (SELECT MIN(rowid) FROM session_racquets GROUP BY sessionId)")
            }
        }

        /** Tennis Vision (Chris, 15 Nov): courts, and which court each vision session was on. Nothing else changes. */
        val MIGRATION_2_3 = object : Migration(2, 3) {
            override fun migrate(db: SupportSQLiteDatabase) {
                db.execSQL("CREATE TABLE IF NOT EXISTS `courts` (`id` INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, `name` TEXT NOT NULL, `layout` INTEGER NOT NULL, `lensMode` TEXT NOT NULL, `indoor` INTEGER NOT NULL, `photo` TEXT)")
                db.execSQL("CREATE TABLE IF NOT EXISTS `vision_labels` (`sessionId` TEXT NOT NULL, `courtId` INTEGER, `indoor` INTEGER NOT NULL, `indoorSent` INTEGER NOT NULL, PRIMARY KEY(`sessionId`), FOREIGN KEY(`courtId`) REFERENCES `courts`(`id`) ON UPDATE NO ACTION ON DELETE SET NULL )")
                db.execSQL("CREATE INDEX IF NOT EXISTS `index_vision_labels_courtId` ON `vision_labels` (`courtId`)")
            }
        }
    }
}
