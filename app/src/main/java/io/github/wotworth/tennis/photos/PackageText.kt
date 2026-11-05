package io.github.wotworth.tennis.photos

import io.github.wotworth.tennis.data.StringSpec
import java.util.Locale

/**
 * PHO-10: reads brand, model, gauge and material from the text on a string package (what ML Kit
 * found). Pure and unit-tested; the result is only a pre-fill for Chris to check.
 */
object PackageText {
    /** Known string brands, longest first so "Weiss Cannon" wins over shorter matches (tunable list). */
    val BRANDS = listOf(
        "Weiss Cannon", "Signum Pro", "Boris Becker", "Kirschbaum", "Tecnifibre", "Technifibre", "Polyfibre", "Toroline", "Isospeed",
        "Babolat", "Luxilon", "Solinco", "Wilson", "Yonex", "Prince", "Gamma", "Volkl", "Völkl", "Dunlop", "Diadem", "Ashaway",
        "Pacific", "Gosen", "Mantis", "Head", "MSV", "Topspin", "Klip", "Genesis", "Restring", "Alpha",
    ).sortedByDescending { it.length }

    /** Gauge from millimetres (ITF bands; PHO-10). */
    fun gaugeFromMm(mm: Double): String = when {
        mm >= 1.41 -> "15"
        mm >= 1.34 -> "15L"
        mm >= 1.26 -> "16"
        mm >= 1.22 -> "16L"
        mm >= 1.16 -> "17"
        mm >= 1.10 -> "18"
        else -> "19"
    }

    private val mmRe = Regex("""\b(1[.,][0-4]\d)\s*mm\b""", RegexOption.IGNORE_CASE)
    private val gaugeRe = Regex("""\b(1[5-9]L?)\s*(?:g|ga|gauge)?\b""", RegexOption.IGNORE_CASE)
    private val gaugeWordRe = Regex("""\bgauge\s*[:\-]?\s*(1[5-9]L?)\b""", RegexOption.IGNORE_CASE)
    /** Luxilon and others print the diameter as "125" or "1.25". */
    private val bareMmRe = Regex("""\b(1[1-4]\d)\b""")

    private val materials = listOf(
        "natural gut" to listOf("natural gut", "natural-gut", "beef gut", "vs gut"),
        "synthetic gut" to listOf("synthetic gut", "synthetic-gut", "nylon"),
        "multifilament" to listOf("multifilament", "multi-filament", "multifibre", "multifiber"),
        "Kevlar/aramid" to listOf("kevlar", "aramid"),
        "co-poly" to listOf("co-poly", "copoly", "co-polyester", "copolyester"),
        "polyester" to listOf("polyester", "monofilament", "poly "),
    )

    fun material(text: String): String {
        val t = " " + text.lowercase(Locale.US) + " "
        return materials.firstOrNull { (_, keys) -> keys.any { it in t } }?.first ?: ""
    }

    fun gauge(text: String): String {
        gaugeWordRe.find(text)?.let { return it.groupValues[1].uppercase(Locale.US) }
        mmRe.find(text)?.let { return gaugeFromMm(it.groupValues[1].replace(',', '.').toDouble()) }
        gaugeRe.find(text)?.let { return it.groupValues[1].uppercase(Locale.US) }
        bareMmRe.find(text)?.let { return gaugeFromMm(it.groupValues[1].toInt() / 100.0) }
        return ""
    }

    fun brand(text: String): String {
        val lower = text.lowercase(Locale.US)
        val b = BRANDS.firstOrNull { Regex("""\b${Regex.escape(it.lowercase(Locale.US))}\b""").containsMatchIn(lower) } ?: return ""
        return if (b == "Technifibre") "Tecnifibre" else if (b == "Völkl") "Volkl" else b
    }

    /**
     * The model: the most prominent remaining line (ML Kit lists the biggest text early) once the
     * brand, gauge, sizes and marketing words are taken out; known models from earlier jobs win.
     */
    fun model(text: String, brand: String, known: List<String> = emptyList()): String {
        known.filter { it.isNotBlank() }.sortedByDescending { it.length }.firstOrNull { text.contains(it, ignoreCase = true) }?.let { return it }
        val noise = Regex("""\b(tennis|string|strings|set|12\s*m|12m|40\s*ft|40'|200\s*m|made in|belgium|germany|japan|taiwan|usa|gauge|mm|ga|reel|professional)\b""", RegexOption.IGNORE_CASE)
        return text.lines().asSequence()
            .map { l -> var x = l; if (brand.isNotBlank()) x = x.replace(Regex(Regex.escape(brand), RegexOption.IGNORE_CASE), " "); x }
            .map { it.replace(mmRe, " ").replace(gaugeRe, " ").replace(noise, " ").replace(Regex("""[^\p{L}\p{N}\- ]"""), " ").replace(Regex("""\s+"""), " ").trim() }
            .filter { it.length in 3..28 && it.any(Char::isLetter) && material(it).isEmpty() }
            .firstOrNull()?.let(::titleCase) ?: ""
    }

    /** ALL-CAPS package text in title case; short words and parts with digits stay capitals ("RPM", "Hyper-G"). */
    private fun titleCase(s: String) = if (s == s.uppercase(Locale.US)) s.split(' ').joinToString(" ") { w ->
        w.split('-').joinToString("-") { p ->
            if (p.any(Char::isDigit) || p.length <= 3) p.uppercase(Locale.US) else p.lowercase(Locale.US).replaceFirstChar { it.titlecase(Locale.US) }
        }
    } else s

    fun read(text: String, knownModels: List<String> = emptyList()): StringSpec {
        val b = brand(text)
        return StringSpec(b, model(text, b, knownModels), gauge(text), material(text))
    }
}
