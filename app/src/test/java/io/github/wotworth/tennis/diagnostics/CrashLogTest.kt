package io.github.wotworth.tennis.diagnostics

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.time.Instant

/** NFR-20 */
class CrashLogTest {

    @get:Rule val tmp = TemporaryFolder()

    private fun entry(log: CrashLog, n: Int) = log.format(
        throwable = IllegalStateException("boom $n"),
        threadName = "main",
        appVersion = "0.0.7 (7)",
        androidVersion = "17 (API 37)",
        device = "samsung SM-S931U",
        time = Instant.parse("2026-11-02T10:15:30Z"),
    )

    @Test fun entryHasTimeVersionsAndStackTrace() {
        val log = CrashLog(tmp.root)
        val text = entry(log, 1)
        assertTrue(text.contains("time: 2026-11-02T10:15:30Z"))
        assertTrue(text.contains("app: 0.0.7 (7)"))
        assertTrue(text.contains("android: 17 (API 37)"))
        assertTrue(text.contains("java.lang.IllegalStateException: boom 1"))
        assertTrue(text.contains("at io.github.wotworth.tennis.diagnostics.CrashLogTest"))
    }

    @Test fun keepsOnlyTheLast20Entries() {
        val log = CrashLog(tmp.root)
        repeat(25) { log.append(entry(log, it)) }
        val entries = log.entries()
        assertEquals(CrashLog.MAX_ENTRIES, entries.size)
        assertTrue(entries.first().contains("boom 5"))
        assertTrue(entries.last().contains("boom 24"))
    }

    @Test fun survivesANewInstance() {
        CrashLog(tmp.root).apply { append(entry(this, 1)) }
        assertEquals(1, CrashLog(tmp.root).entries().size)
    }

    @Test fun emptyWhenNothingLogged() {
        assertEquals(emptyList<String>(), CrashLog(tmp.root).entries())
    }

    @Test fun shareTextIsNewestFirst() {
        val log = CrashLog(tmp.root)
        repeat(3) { log.append(entry(log, it)) }
        val share = log.shareText()
        assertTrue(share.indexOf("boom 2") < share.indexOf("boom 0"))
    }
}
