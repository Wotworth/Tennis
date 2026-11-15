package io.github.wotworth.tennis.vision

import java.time.Instant

/**
 * Chris, 15 Nov: "If I pick a court before playing, label the next vision session that overlaps
 * that time with its name." A session matches when it ends after the pick and starts no later
 * than [windowHours] after it; the earliest such session that has no court yet wins.
 */
object CourtPick {
    data class Span(val id: String, val startMillis: Long, val endMillis: Long)

    fun span(v: VisionSession): Span? = runCatching {
        val start = Instant.parse(v.startUtc.replace(Regex("\\.\\d+Z$"), "Z")).toEpochMilli()
        Span(v.id, start, start + ((v.rallies.maxOfOrNull { it.stop } ?: 0.0) * 1000).toLong())
    }.getOrNull()

    fun match(sessions: List<Span>, pickMillis: Long, labelled: Set<String>, windowHours: Float): String? =
        sessions.filter { it.id !in labelled && it.endMillis >= pickMillis && it.startMillis <= pickMillis + (windowHours * 3_600_000).toLong() }
            .minByOrNull { it.startMillis }?.id
}
