package io.github.wotworth.tennis.data

import androidx.room.Room
import androidx.room.testing.MigrationTestHelper
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/** DAT-04: data logged with v0.1–v0.5 (schema 1) survives the v0.4 spec update (schema 2). */
@RunWith(AndroidJUnit4::class)
class MigrationTest {
    @get:Rule val helper = MigrationTestHelper(InstrumentationRegistry.getInstrumentation(), TennisDatabase::class.java)

    @Test fun oneToTwoKeepsRacquetsJobsAndSessions() {
        helper.createDatabase("m.db", 1).use { db ->
            db.execSQL("INSERT INTO racquets (id, name, model, colour, position) VALUES (1, 'Black Blade #1', 'Blade 98', 'black', 0), (2, 'Black Blade #2', 'Blade 98', 'black', 1)")
            db.execSQL("INSERT INTO string_jobs (id, racquetId, date, mains_brand, mains_model, mains_gauge, mains_material, hybrid, crosses_brand, crosses_model, crosses_gauge, crosses_material, mainsLb, crossesLb, shop, priceCents, notes) " +
                "VALUES (1, 1, 20000, 'Solinco', 'Hyper-G', '16L', 'co-poly', 0, '', '', '', '', 55.0, 53.0, 'Racquet Lab', 3850, '')")
            db.execSQL("INSERT INTO sessions (id, date, minutes, feel, source, notes) VALUES (1, 20001, 90, 4, 'manual', ''), (2, 20002, 120, NULL, 'manual', '')")
            // Session 1 used one racquet; session 2 used both (allowed in v0.3), #1 chosen first.
            db.execSQL("INSERT INTO session_racquets (sessionId, racquetId) VALUES (1, 2), (2, 1), (2, 2)")
        }
        helper.runMigrationsAndValidate("m.db", 2, true, TennisDatabase.MIGRATION_1_2).use { db ->
            db.query("SELECT COUNT(*) FROM racquets WHERE retired = 0").use { it.moveToFirst(); assertEquals(2, it.getInt(0)) }
            db.query("SELECT COUNT(*) FROM string_jobs").use { it.moveToFirst(); assertEquals(1, it.getInt(0)) }
            db.query("SELECT sessionId, racquetId FROM session_racquets ORDER BY sessionId").use { c ->
                val rows = buildList { while (c.moveToNext()) add(c.getLong(0) to c.getLong(1)) }
                assertEquals(listOf(1L to 2L, 2L to 1L), rows)
            }
        }
        // The app opens the migrated file normally.
        val ctx = InstrumentationRegistry.getInstrumentation().targetContext
        val db = Room.databaseBuilder(ctx, TennisDatabase::class.java, "m.db").addMigrations(TennisDatabase.MIGRATION_1_2).build()
        val r = runBlocking { db.dao().racquetsNow() }
        assertEquals(listOf("Black Blade #1", "Black Blade #2"), r.map { it.name })
        assertFalse(r.any { it.retired })
        db.close()
    }
}
