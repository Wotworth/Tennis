package io.github.wotworth.tennis.vision

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * The Tennis Vision cloud service (TV-API, TV-PH-4; Chris, 22 Nov: deploy it this weekend).
 * One host only (TV-API-06): the Worker's address is built into the app once it is deployed, and the
 * network security config allows exactly that host besides api.anthropic.com. Until then [HOST] is
 * empty and nothing here makes a network call.
 */
object CloudConfig {
    /** e.g. "tennis-api.<name>.workers.dev": set at release once Chris has deployed the Worker. */
    const val HOST = ""
    val enabled get() = HOST.isNotEmpty()
}

/** The app's read passphrase, encrypted with a key that never leaves the Android Keystore (TV-API-03). */
class CloudTokenStore(context: Context, private val key: () -> SecretKey = ::keystoreKey) {
    private val sp = context.getSharedPreferences("secure", Context.MODE_PRIVATE)
    fun get(): String? = sp.getString(NAME, null)?.let { runCatching { decrypt(it) }.getOrNull() }
    fun set(token: String) = sp.edit().putString(NAME, encrypt(token.trim())).apply()
    fun clear() = sp.edit().remove(NAME).apply()
    fun isSet() = sp.contains(NAME)

    private fun encrypt(plain: String): String {
        val c = Cipher.getInstance(TRANSFORM).apply { init(Cipher.ENCRYPT_MODE, key()) }
        return Base64.encodeToString(c.iv + c.doFinal(plain.toByteArray()), Base64.NO_WRAP)
    }
    private fun decrypt(stored: String): String {
        val all = Base64.decode(stored, Base64.NO_WRAP)
        val c = Cipher.getInstance(TRANSFORM).apply { init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(128, all, 0, 12)) }
        return String(c.doFinal(all, 12, all.size - 12))
    }

    companion object {
        private const val NAME = "cloud_read_token"
        private const val ALIAS = "tennis-cloud-token"
        private const val TRANSFORM = "AES/GCM/NoPadding"
        fun keystoreKey(): SecretKey {
            val ks = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
            (ks.getKey(ALIAS, null) as? SecretKey)?.let { return it }
            val g = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
            g.init(KeyGenParameterSpec.Builder(ALIAS, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM).setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE).setKeySize(256).build())
            return g.generateKey()
        }
    }
}

class CloudError(val code: Int, message: String) : Exception(message)

/** HTTPS to the one Worker host, with the read token. [open] is replaceable in tests. */
class CloudClient(
    private val host: String, private val token: String,
    private val open: (URL) -> HttpURLConnection = { it.openConnection() as HttpURLConnection },
) {
    fun get(path: String): String = call("GET", path, null)
    fun post(path: String, body: JSONObject?): String = call("POST", path, body)

    /** A file the Worker linked to (signed, short-lived, on its own host: TV-API-06). */
    fun download(url: String, to: File) {
        val u = URL(url)
        require(u.protocol == "https" && u.host == host) { "only the Worker's own host" }
        val c = open(u).apply { connectTimeout = TIMEOUT; readTimeout = TIMEOUT }
        try {
            if (c.responseCode != 200) throw CloudError(c.responseCode, "download failed")
            to.parentFile?.mkdirs()
            c.inputStream.use { i -> to.outputStream().use { o -> i.copyTo(o) } }
        } finally { c.disconnect() }
    }

    private fun call(method: String, path: String, body: JSONObject?): String {
        val c = open(URL("https://$host$path")).apply {
            requestMethod = method; connectTimeout = TIMEOUT; readTimeout = TIMEOUT
            setRequestProperty("Authorization", "Bearer $token")
            if (body != null) { doOutput = true; setRequestProperty("Content-Type", "application/json") }
        }
        try {
            if (body != null) c.outputStream.use { it.write(body.toString().toByteArray()) }
            val code = c.responseCode
            val text = (if (code in 200..299) c.inputStream else c.errorStream)?.use { it.bufferedReader().readText() } ?: ""
            if (code !in 200..299) throw CloudError(code, if (code == 401) "the passphrase is not the Worker's read passphrase" else "the cloud said $code")
            return text
        } finally { c.disconnect() }
    }

    companion object { const val TIMEOUT = 20_000 }
}

/**
 * One check with the cloud: what is new since the last one, kept in the app's own files (cloud/), and
 * the answers waiting in the outbox sent. The app shows them; it posts no notifications (TV-UP-03).
 */
class CloudSync(private val context: Context, private val client: CloudClient) {
    private val dir = File(context.filesDir, "cloud")
    data class Result(val sessions: Int, val newSessions: List<String>, val corners: Int, val newCorners: Int, val sent: Int)

    fun run(): Result {
        dir.mkdirs()
        val sent = flushOutbox()
        val sessions = JSONArray(client.get("/sessions"))
        File(dir, "sessions.json").writeText(sessions.toString())
        val seen = seen("seenSessions")
        val fresh = (0 until sessions.length()).map { sessions.getJSONObject(it) }.filter { it.getString("id") !in seen }
        save("seenSessions", seen + fresh.map { it.getString("id") })
        val corners = JSONArray(client.get("/calibration/next"))
        File(dir, "corners.json").writeText(corners.toString())
        val seenC = seen("seenCorners")
        var newC = 0
        for (i in 0 until corners.length()) {
            val o = corners.getJSONObject(i)
            val pic = File(dir, "corners/${o.getInt("id")}.jpg")
            if (!pic.exists()) runCatching { client.download(o.getString("url"), pic) }
            if (o.getInt("id").toString() !in seenC) newC++
        }
        save("seenCorners", seenC + (0 until corners.length()).map { corners.getJSONObject(it).getInt("id").toString() })
        return Result(sessions.length(), fresh.map { it.optString("headline", it.getString("id")) }, corners.length(), newC, sent)
    }

    /** The answers queued while offline (ball checks, corners, flags), in order; each removed once sent. */
    fun flushOutbox(): Int {
        val box = Outbox(context.filesDir)
        val items = box.read()
        var sent = 0
        for (i in 0 until items.length()) {
            val o = items.getJSONObject(i)
            runCatching { client.post(o.getString("path"), o.getJSONObject("body")) }.onSuccess { sent++ }.onFailure { return sent.also { box.keepFrom(i) } }
        }
        box.keepFrom(items.length())
        return sent
    }

    private fun seen(name: String): Set<String> = File(dir, "$name.txt").takeIf { it.exists() }?.readLines()?.filter { it.isNotBlank() }?.toSet() ?: emptySet()
    private fun save(name: String, s: Set<String>) = File(dir, "$name.txt").writeText(s.joinToString("\n"))

    companion object {
        /** The cached list of cloud sessions (id, headline) for the Sessions page. */
        fun cachedSessions(context: Context): List<Pair<String, String>> = runCatching {
            val a = JSONArray(File(context.filesDir, "cloud/sessions.json").readText())
            (0 until a.length()).map { a.getJSONObject(it) }.map { it.getString("id") to it.optString("headline", it.getString("id")) }
        }.getOrDefault(emptyList())

        fun cachedCorners(context: Context): String? = runCatching { File(context.filesDir, "cloud/corners.json").readText() }.getOrNull()
        fun cornerPicture(context: Context, id: Int): File = File(context.filesDir, "cloud/corners/$id.jpg")
    }
}
