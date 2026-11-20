package io.github.wotworth.tennis.vision

import java.math.BigDecimal
import java.math.RoundingMode

/**
 * A small JSON reader and writer in plain Kotlin (no Android), for the files the app swaps with
 * MATLAB: Tuesday's field notes (FieldNotes.kt) and the accuracy results (Accuracy.kt).
 * Objects read as LinkedHashMap<String, Any?> (key order kept), arrays as List<Any?>, numbers as
 * Double, plus String, Boolean and null.
 */
object MiniJson {

    fun parse(text: String): Any? = Reader(text).run { val v = value(); space(); require(i == s.length) { "extra text at $i" }; v }

    /**
     * Writes [v] with two-space indents; an object or array holding only plain values goes on one
     * line. Numbers are rounded to [decimals] places, whole numbers written without a point.
     */
    fun write(v: Any?, decimals: Int = 6): String = StringBuilder().also { out(it, v, 0, decimals) }.append('\n').toString()

    fun number(d: Double, decimals: Int = 6): String {
        if (d.isNaN() || d.isInfinite()) return "null"
        val b = BigDecimal(d).setScale(decimals, RoundingMode.HALF_UP).stripTrailingZeros()
        return if (b.signum() == 0) "0" else b.toPlainString()
    }

    private fun flat(v: Any?) = when (v) {
        is Map<*, *> -> v.values.none { it is Map<*, *> || it is List<*> }
        is List<*> -> v.none { it is Map<*, *> || it is List<*> }
        else -> true
    }

    private fun out(sb: StringBuilder, v: Any?, depth: Int, dec: Int) {
        val pad = "  ".repeat(depth + 1)
        when (v) {
            null -> sb.append("null")
            is Boolean -> sb.append(v)
            is Int -> sb.append(v)
            is Long -> sb.append(v)
            is Number -> sb.append(number(v.toDouble(), dec))
            is String -> str(sb, v)
            is Map<*, *> -> {
                if (v.isEmpty()) { sb.append("{}"); return }
                val one = flat(v)
                sb.append('{')
                v.entries.forEachIndexed { k, (key, value) ->
                    if (k > 0) sb.append(if (one) ", " else ",")
                    if (!one) sb.append('\n').append(pad)
                    str(sb, key.toString()); sb.append(": "); out(sb, value, depth + 1, dec)
                }
                if (!one) sb.append('\n').append("  ".repeat(depth))
                sb.append('}')
            }
            is List<*> -> {
                if (v.isEmpty()) { sb.append("[]"); return }
                val one = flat(v)
                sb.append('[')
                v.forEachIndexed { k, value ->
                    if (k > 0) sb.append(if (one) ", " else ",")
                    if (!one) sb.append('\n').append(pad)
                    out(sb, value, depth + 1, dec)
                }
                if (!one) sb.append('\n').append("  ".repeat(depth))
                sb.append(']')
            }
            else -> str(sb, v.toString())
        }
    }

    private fun str(sb: StringBuilder, s: String) {
        sb.append('"')
        for (c in s) when {
            c == '"' -> sb.append("\\\"")
            c == '\\' -> sb.append("\\\\")
            c == '\n' -> sb.append("\\n")
            c == '\r' -> sb.append("\\r")
            c == '\t' -> sb.append("\\t")
            c < ' ' -> sb.append("\\u%04x".format(c.code))
            else -> sb.append(c)
        }
        sb.append('"')
    }

    private class Reader(val s: String) {
        var i = 0
        fun space() { while (i < s.length && s[i].isWhitespace()) i++ }
        fun value(): Any? {
            space()
            require(i < s.length) { "unexpected end" }
            return when (val c = s[i]) {
                '{' -> obj()
                '[' -> arr()
                '"' -> string()
                't' -> word("true", true)
                'f' -> word("false", false)
                'n' -> word("null", null)
                'N' -> word("NaN", null)    // MATLAB can write NaN; read it as a missing number
                else -> if (c == '-' || c.isDigit()) num() else error("unexpected '$c' at $i")
            }
        }
        fun word(w: String, v: Any?): Any? { require(s.startsWith(w, i)) { "bad value at $i" }; i += w.length; return v }
        fun num(): Double {
            val start = i
            while (i < s.length && (s[i].isDigit() || s[i] in "+-.eE")) i++
            return s.substring(start, i).toDouble()
        }
        fun string(): String {
            i++
            val sb = StringBuilder()
            while (true) {
                require(i < s.length) { "unterminated string" }
                val c = s[i++]
                when (c) {
                    '"' -> return sb.toString()
                    '\\' -> {
                        when (val e = s[i++]) {
                            'n' -> sb.append('\n'); 't' -> sb.append('\t'); 'r' -> sb.append('\r')
                            'b' -> sb.append('\b'); 'f' -> sb.append('\u000C')
                            'u' -> { sb.append(s.substring(i, i + 4).toInt(16).toChar()); i += 4 }
                            else -> sb.append(e)
                        }
                    }
                    else -> sb.append(c)
                }
            }
        }
        fun obj(): Map<String, Any?> {
            i++
            val m = LinkedHashMap<String, Any?>()
            space()
            if (s[i] == '}') { i++; return m }
            while (true) {
                space()
                val k = string()
                space(); require(s[i] == ':') { "expected ':' at $i" }; i++
                m[k] = value()
                space()
                when (s[i++]) { ',' -> continue; '}' -> return m; else -> error("expected ',' or '}' at ${i - 1}") }
            }
        }
        fun arr(): List<Any?> {
            i++
            val l = ArrayList<Any?>()
            space()
            if (s[i] == ']') { i++; return l }
            while (true) {
                l += value()
                space()
                when (s[i++]) { ',' -> continue; ']' -> return l; else -> error("expected ',' or ']' at ${i - 1}") }
            }
        }
    }
}

/** Reading helpers, tolerant of missing or oddly-typed values. */
internal fun Any?.obj(): Map<String, Any?>? = (this as? Map<*, *>)?.let { m -> m.entries.associate { it.key.toString() to it.value } }
internal fun Map<String, Any?>.num(k: String): Double? = when (val v = this[k]) { is Number -> v.toDouble(); is String -> v.toDoubleOrNull(); is List<*> -> (v.singleOrNull() as? Number)?.toDouble(); else -> null }
internal fun Map<String, Any?>.text(k: String): String? = when (val v = this[k]) { is String -> v; null -> null; is List<*> -> null; else -> v.toString() }
internal fun Map<String, Any?>.bool(k: String): Boolean? = when (val v = this[k]) { is Boolean -> v; is Number -> v.toDouble() != 0.0; is String -> v.equals("true", true); else -> null }
/** MATLAB writes a one-element list as a lone object; read both, and [] / null as empty. */
internal fun Any?.objs(): List<Map<String, Any?>> = when (this) {
    is List<*> -> mapNotNull { it.obj() }
    is Map<*, *> -> listOfNotNull(obj())
    else -> emptyList()
}
internal fun Any?.nums(): List<Double?> = when (this) {
    is List<*> -> map { (it as? Number)?.toDouble() }
    is Number -> listOf(toDouble())
    else -> emptyList()
}
