package io.github.wotworth.tennis.data

import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.io.InputStream
import java.io.OutputStream
import java.util.zip.ZipEntry
import java.util.zip.ZipInputStream
import java.util.zip.ZipOutputStream

data class BackupData(
    val racquets: List<Racquet> = emptyList(),
    val jobs: List<StringJob> = emptyList(),
    val sessions: List<Session> = emptyList(),
    val sessionRacquets: List<SessionRacquet> = emptyList(),
    val proposals: List<Proposal> = emptyList(),
    val cues: List<Cue> = emptyList(),
    val strings: List<StringItem> = emptyList(),
)

/**
 * DAT-02: one zip with `data.json` (every record, with a schema version) and the photos.
 * The API key and the settings are not exported (PHO-22).
 */
object Backup {
    const val SCHEMA = 2

    fun toJson(b: BackupData): JSONObject = JSONObject().apply {
        put("app", "io.github.wotworth.tennis")
        put("schema", SCHEMA)
        put("racquets", JSONArray(b.racquets.map { JSONObject().put("id", it.id).put("name", it.name).put("model", it.model).put("colour", it.colour).put("position", it.position).put("retired", it.retired) }))
        put("jobs", JSONArray(b.jobs.map { j ->
            JSONObject().put("id", j.id).put("racquetId", j.racquetId).put("date", j.date).put("mains", spec(j.mains)).put("hybrid", j.hybrid)
                .put("crosses", spec(j.crossesOwn)).put("mainsLb", j.mainsLb ?: JSONObject.NULL).put("crossesLb", j.crossesLb ?: JSONObject.NULL)
                .put("shop", j.shop).put("priceCents", j.priceCents ?: JSONObject.NULL).put("notes", j.notes)
                .put("mainsPhoto", j.mainsPhoto ?: JSONObject.NULL).put("crossesPhoto", j.crossesPhoto ?: JSONObject.NULL)
        }))
        put("sessions", JSONArray(b.sessions.map { s ->
            JSONObject().put("id", s.id).put("date", s.date).put("minutes", s.minutes).put("feel", s.feel ?: JSONObject.NULL).put("source", s.source)
                .put("startMillis", s.startMillis ?: JSONObject.NULL).put("endMillis", s.endMillis ?: JSONObject.NULL)
                .put("avgHr", s.avgHr ?: JSONObject.NULL).put("maxHr", s.maxHr ?: JSONObject.NULL).put("steps", s.steps ?: JSONObject.NULL).put("notes", s.notes)
        }))
        put("sessionRacquets", JSONArray(b.sessionRacquets.map { JSONObject().put("sessionId", it.sessionId).put("racquetId", it.racquetId) }))
        put("proposals", JSONArray(b.proposals.map { p ->
            JSONObject().put("id", p.id).put("startMillis", p.startMillis).put("endMillis", p.endMillis).put("source", p.source)
                .put("avgHr", p.avgHr ?: JSONObject.NULL).put("maxHr", p.maxHr ?: JSONObject.NULL).put("steps", p.steps ?: JSONObject.NULL)
                .put("state", p.state).put("createdMillis", p.createdMillis)
        }))
        put("cues", JSONArray(b.cues.map { JSONObject().put("id", it.id).put("heading", it.heading).put("text", it.text).put("pinned", it.pinned).put("position", it.position) }))
        put("strings", JSONArray(b.strings.map { JSONObject().put("id", it.id).put("spec", spec(it.spec)).put("photo", it.photo ?: JSONObject.NULL).put("notes", it.notes) }))
    }

    private fun spec(s: StringSpec) = JSONObject().put("brand", s.brand).put("model", s.model).put("gauge", s.gauge).put("material", s.material)
    private fun spec(o: JSONObject?) = if (o == null) StringSpec() else StringSpec(o.optString("brand"), o.optString("model"), o.optString("gauge"), o.optString("material"))
    private fun JSONObject.str(k: String): String? = if (isNull(k) || !has(k)) null else getString(k)
    private fun JSONObject.dbl(k: String): Double? = if (isNull(k) || !has(k)) null else getDouble(k)
    private fun JSONObject.lng(k: String): Long? = if (isNull(k) || !has(k)) null else getLong(k)
    private fun JSONObject.int(k: String): Int? = if (isNull(k) || !has(k)) null else getInt(k)
    private fun <T> JSONArray?.map(f: (JSONObject) -> T): List<T> = if (this == null) emptyList() else (0 until length()).map { f(getJSONObject(it)) }

    fun fromJson(o: JSONObject): BackupData {
        require(o.optString("app") == "io.github.wotworth.tennis") { "This file isn't a tennis backup." }
        require(o.optInt("schema") <= SCHEMA) { "This backup is from a newer version of the app." }
        return BackupData(
            racquets = o.optJSONArray("racquets").map { Racquet(it.getLong("id"), it.getString("name"), it.optString("model"), it.optString("colour"), it.optInt("position"), it.optBoolean("retired")) },
            jobs = o.optJSONArray("jobs").map {
                StringJob(it.getLong("id"), it.getLong("racquetId"), it.getLong("date"), spec(it.optJSONObject("mains")), it.optBoolean("hybrid"),
                    spec(it.optJSONObject("crosses")), it.dbl("mainsLb"), it.dbl("crossesLb"), it.optString("shop"), it.lng("priceCents"),
                    it.optString("notes"), it.str("mainsPhoto"), it.str("crossesPhoto"))
            },
            sessions = o.optJSONArray("sessions").map {
                Session(it.getLong("id"), it.getLong("date"), it.getInt("minutes"), it.int("feel"), it.optString("source", "manual"),
                    it.lng("startMillis"), it.lng("endMillis"), it.int("avgHr"), it.int("maxHr"), it.lng("steps"), it.optString("notes"))
            },
            sessionRacquets = o.optJSONArray("sessionRacquets").map { SessionRacquet(it.getLong("sessionId"), it.getLong("racquetId")) },
            proposals = o.optJSONArray("proposals").map {
                Proposal(it.getLong("id"), it.getLong("startMillis"), it.getLong("endMillis"), it.getString("source"), it.int("avgHr"), it.int("maxHr"),
                    it.lng("steps"), it.optString("state", "waiting"), it.optLong("createdMillis"))
            },
            cues = o.optJSONArray("cues").map { Cue(it.getLong("id"), it.getString("heading"), it.getString("text"), it.optBoolean("pinned"), it.optInt("position")) },
            strings = o.optJSONArray("strings").map { StringItem(it.getLong("id"), spec(it.optJSONObject("spec")), it.str("photo"), it.optString("notes")) },
        )
    }

    /** Writes the zip: data.json, then photos/<name> for every photo file in [photoDir]. */
    fun write(b: BackupData, photoDir: File, out: OutputStream) {
        ZipOutputStream(out).use { z ->
            z.putNextEntry(ZipEntry("data.json")); z.write(toJson(b).toString(1).toByteArray()); z.closeEntry()
            photoDir.listFiles()?.filter { it.isFile }?.forEach { f ->
                z.putNextEntry(ZipEntry("photos/${f.name}")); f.inputStream().use { it.copyTo(z) }; z.closeEntry()
            }
        }
    }

    /** Reads a zip written by [write]; photos are unpacked into [photoDir] (names only, no paths). */
    fun read(input: InputStream, photoDir: File): BackupData {
        var data: BackupData? = null
        ZipInputStream(input).use { z ->
            while (true) {
                val e = z.nextEntry ?: break
                when {
                    e.name == "data.json" -> data = fromJson(JSONObject(z.readBytes().toString(Charsets.UTF_8)))
                    e.name.startsWith("photos/") && !e.isDirectory -> {
                        val name = File(e.name).name
                        if (name.isNotBlank() && !name.startsWith(".")) { photoDir.mkdirs(); File(photoDir, name).outputStream().use { z.copyTo(it) } }
                    }
                }
            }
        }
        return data ?: throw IllegalArgumentException("This file isn't a tennis backup.")
    }
}
