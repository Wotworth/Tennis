// Copied from the Zune player (Wotworth/zune diagnostics/CrashLog.kt at f2d9237), package renamed; changes noted below. (VIS, section 3)
package io.github.wotworth.tennis.diagnostics

import java.io.File
import java.io.PrintWriter
import java.io.StringWriter
import java.time.Instant

/**
 * NFR-20: uncaught exceptions are written to a log file in app storage, keeping
 * the last [MAX_ENTRIES] entries. Each entry has a timestamp, the app and
 * Android versions, and the stack trace.
 */
class CrashLog(dir: File) {

    val file = File(dir, "crash-log.txt")

    /** Builds one entry. Kept separate from [append] so tests can check the format. */
    fun format(
        throwable: Throwable,
        threadName: String,
        appVersion: String,
        androidVersion: String,
        device: String,
        time: Instant,
    ): String {
        val trace = StringWriter().also { throwable.printStackTrace(PrintWriter(it)) }.toString().trimEnd()
        return buildString {
            appendLine("time: $time")
            appendLine("app: $appVersion")
            appendLine("android: $androidVersion")
            appendLine("device: $device")
            appendLine("thread: $threadName")
            append(trace)
        }
    }

    /** Adds an entry and drops the oldest beyond [MAX_ENTRIES]. Safe to call while crashing. */
    @Synchronized
    fun append(entry: String) {
        file.parentFile?.mkdirs()
        val kept = (entries() + entry).takeLast(MAX_ENTRIES)
        val tmp = File(file.parentFile, file.name + ".tmp")
        tmp.writeText(kept.joinToString(SEPARATOR, postfix = "\n"))
        if (!tmp.renameTo(file)) {
            file.writeText(tmp.readText())
            tmp.delete()
        }
    }

    /** Entries, oldest first. */
    @Synchronized
    fun entries(): List<String> {
        if (!file.exists()) return emptyList()
        return file.readText().split(SEPARATOR).map { it.trim() }.filter { it.isNotEmpty() }
    }

    /** All entries, newest first, as one block of text for the share sheet. */
    fun shareText(): String = entries().reversed().joinToString(SEPARATOR)

    companion object {
        const val MAX_ENTRIES = 20
        const val SEPARATOR = "\n\n========================================\n\n"
    }
}
