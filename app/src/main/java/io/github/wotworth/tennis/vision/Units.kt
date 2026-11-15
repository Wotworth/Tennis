package io.github.wotworth.tennis.vision

import kotlin.math.roundToInt

/** TV-ARCH-11: SI inside, mph / feet / rpm on screen. */
object Units {
    const val MPH_PER_MS = 2.236936
    const val FT_PER_M = 3.280840
    fun mph(ms: Double?) = ms?.let { "${(it * MPH_PER_MS).roundToInt()} mph" } ?: "–"
    fun ft(m: Double?, signed: Boolean = false): String = m?.let {
        val v = it * FT_PER_M
        val s = if (kotlin.math.abs(v) < 10) "%.1f".format(java.util.Locale.US, v) else v.roundToInt().toString()
        (if (signed && v > 0) "+" else "") + s + " ft"
    } ?: "–"
    fun inches(m: Double?) = m?.let { "${(it * FT_PER_M * 12).roundToInt()} in" } ?: "–"
    fun rpm(rpm: Double?, sd: Double?) = if (rpm == null) "–" else "${(rpm / 10).roundToInt() * 10} rpm ± ${(((sd ?: 0.0)) / 10).roundToInt() * 10}"
}
