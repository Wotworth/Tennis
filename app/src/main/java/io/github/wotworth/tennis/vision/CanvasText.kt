package io.github.wotworth.tennis.vision

/**
 * Numbers drawn straight onto a chart are not in the screen's text tree, so the spoof-session test
 * (SpoofOddNumbersTest) cannot read them. Chart code passes them through [log]; nothing is kept
 * unless a test turns [record] on.
 */
object CanvasText {
    @Volatile var record = false
    val seen: MutableList<String> = java.util.Collections.synchronizedList(mutableListOf())
    fun log(text: String): String { if (record) seen += text; return text }
}
