package io.github.wotworth.tennis.vision

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue

/**
 * The app's side of the detector improvement loop and of opponents (Chris, 15 Nov). The app only
 * posts what Chris tapped; the PC pulls it and does the work; the Worker computes nothing.
 * Until the cloud API is deployed (TV-PH-4) every post waits in [Outbox] on the phone.
 */
data class CheckItem(val id: Int, val file: String, val predX: Double, val predY: Double)

/** A "Ball check" answer: the marker is on the ball, the ball is elsewhere (x, y in crop pixels), or no ball. */
sealed interface CheckAnswer {
    data object Ok : CheckAnswer
    data class Moved(val x: Double, val y: Double) : CheckAnswer
    data object NoBall : CheckAnswer
}

/** "This looks wrong" reasons, exactly as the Worker accepts them. */
val LOOKS_WRONG_REASONS = listOf("wrong speed", "wrong call", "not my shot", "not a real shot")

/**
 * Posts waiting for the cloud: JSON lines in the app's own storage. Holds taps only (check
 * answers, flags, the indoor flag, opponent choices by id): never a court or opponent name.
 */
class Outbox(private val dir: File) {
    private val file get() = File(dir, "vision-outbox.json")
    @Synchronized fun add(path: String, body: JSONObject) {
        val a = read(); a.put(JSONObject().put("path", path).put("body", body)); file.writeText(a.toString())
    }
    @Synchronized fun read(): JSONArray = if (file.exists()) JSONArray(file.readText()) else JSONArray()
    fun size() = read().length()
    /** Drop the first n entries (sent to the cloud). */
    @Synchronized fun keepFrom(n: Int) {
        val a = read();  val b = JSONArray()
        for (i in n until a.length()) b.put(a.get(i))
        file.writeText(b.toString())
    }
}

/**
 * Opponents (Chris, 15 Nov): names are stored only in the cloud database. Until it is deployed
 * the sample keeps them in memory for this run of the app only, so nothing is written to the
 * phone, the repository or a log.
 */
class Opponents {
    data class Opponent(val id: Int, val name: String)
    private val list = mutableListOf<Opponent>()
    private val bySession = mutableMapOf<String, Int?>()
    private var next = 1
    var version by androidx.compose.runtime.mutableIntStateOf(0)
        private set

    fun all(lastPlayed: (Int) -> String?): List<Opponent> =
        list.sortedWith(compareByDescending<Opponent> { lastPlayed(it.id) ?: "" }.thenByDescending { it.id })
    fun add(name: String): Opponent { val o = Opponent(next++, name.trim().replace(Regex("\\s+"), " ")); list += o; version++; return o }
    fun rename(id: Int, name: String) { list.replaceAll { if (it.id == id) it.copy(name = name.trim()) else it }; version++ }
    fun merge(from: Int, into: Int) { bySession.replaceAll { _, v -> if (v == from) into else v }; list.removeAll { it.id == from }; version++ }
    fun delete(id: Int) { bySession.replaceAll { _, v -> if (v == id) null else v }; list.removeAll { it.id == id }; version++ }
    fun choose(session: String, id: Int?) { bySession[session] = id; version++ }
    fun answered(session: String) = session in bySession
    fun of(session: String): Opponent? = bySession[session]?.let { id -> list.firstOrNull { it.id == id } }
    fun sessionsOf(id: Int): List<String> = bySession.filterValues { it == id }.keys.toList()
    fun byId(id: Int) = list.firstOrNull { it.id == id }
}

object CheckJson {
    fun read(text: String): List<CheckItem> {
        val a = JSONObject(text).getJSONArray("checks")
        return (0 until a.length()).map { a.getJSONObject(it) }.map { CheckItem(it.getInt("id"), it.getString("file"), it.getDouble("predX"), it.getDouble("predY")) }
    }
}

object Feedback {
    fun checkBody(id: Int, a: CheckAnswer): JSONObject = when (a) {
        CheckAnswer.Ok -> JSONObject().put("answer", "ok")
        is CheckAnswer.Moved -> JSONObject().put("answer", "moved").put("x", a.x).put("y", a.y)
        CheckAnswer.NoBall -> JSONObject().put("answer", "none")
    }
    fun looksWrong(rally: Int, shot: Int, reason: String): JSONObject {
        require(reason in LOOKS_WRONG_REASONS)
        return JSONObject().put("kind", "looks wrong").put("rally", rally).put("shot", shot).put("reason", reason)
    }
    fun missedShot(rally: Int, t: Double): JSONObject = JSONObject().put("kind", "missed shot").put("rally", rally).put("t", t)
    fun opponent(id: Int?): JSONObject = JSONObject().put("opponentId", id ?: JSONObject.NULL)

    /** The default suggestion: the opponent of the last session at the same court; never chosen automatically. */
    fun suggest(sessionCourt: Long?, history: List<Triple<String, Long?, Int?>>): Int? =
        if (sessionCourt == null) null else history.filter { it.second == sessionCourt && it.third != null }.maxByOrNull { it.first }?.third
}
