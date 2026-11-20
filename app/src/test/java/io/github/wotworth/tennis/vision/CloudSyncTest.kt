package io.github.wotworth.tennis.vision

import androidx.test.core.app.ApplicationProvider
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.File
import java.net.HttpURLConnection
import java.net.URL

/** The app's side of the cloud (Chris, 22 Nov), against a fake Worker: nothing leaves the test. */
@RunWith(RobolectricTestRunner::class)
class CloudSyncTest {
    private val host = "tennis-api.example.workers.dev"
    private val posted = mutableListOf<String>()

    private inner class Fake(u: URL, private val reply: (String, String) -> Pair<Int, ByteArray>) : HttpURLConnection(u) {
        private val sent = ByteArrayOutputStream()
        private var r: Pair<Int, ByteArray>? = null
        private fun go() = r ?: reply(requestMethod, url.path + (url.query?.let { "?$it" } ?: "")).also {
            if (requestMethod == "POST") posted += url.path + " " + sent.toString()
            r = it
        }
        override fun getOutputStream() = sent
        override fun getResponseCode() = go().first
        override fun getInputStream() = ByteArrayInputStream(go().second)
        override fun getErrorStream() = ByteArrayInputStream(go().second)
        override fun connect() {}
        override fun disconnect() {}
        override fun usingProxy() = false
    }

    private fun worker(token: String = "right-passphrase") = CloudClient(host, token) { u ->
        Fake(u) { m, p ->
            when {
                token != "right-passphrase" -> 401 to "{\"error\":\"bad token\"}".toByteArray()
                p == "/sessions" -> 200 to """[{"id":"selftest","headline":"Self-test: the cloud reached your phone"}]""".toByteArray()
                p == "/calibration/next" -> 200 to """[{"id":7,"sessionId":"selftest","cam":1,"picturePath":"calibration/cam1.jpg","width":1920,"height":1080,"support":0.33,"reason":"lines","lines":[[[1,2],[3,4]]],"url":"https://$host/sessions/selftest/files/calibration/cam1.jpg?sig=x"}]""".toByteArray()
                p.startsWith("/sessions/selftest/files/") -> 200 to byteArrayOf(1, 2, 3)
                m == "POST" -> 200 to "{\"ok\":true}".toByteArray()
                else -> 404 to ByteArray(0)
            }
        }
    }

    @Test fun aCheckBringsTheSessionAndTheCornersRequestAndSendsTheAnswers() {
        val ctx = ApplicationProvider.getApplicationContext<android.content.Context>()
        File(ctx.filesDir, "cloud").deleteRecursively()
        val box = Outbox(ctx.filesDir)
        box.keepFrom(box.size())
        box.add("/calibration/7/answer", JSONObject().put("answer", "accepted"))
        val r = CloudSync(ctx, worker()).run()
        assertEquals(1, r.sessions);  assertEquals(listOf("Self-test: the cloud reached your phone"), r.newSessions)
        assertEquals(1, r.corners);  assertEquals(1, r.newCorners);  assertEquals(1, r.sent)
        assertEquals(0, box.size())
        assertTrue(posted.any { it.startsWith("/calibration/7/answer") && it.contains("accepted") })
        assertTrue(CloudSync.cornerPicture(ctx, 7).readBytes().contentEquals(byteArrayOf(1, 2, 3)))
        assertEquals(listOf("selftest" to "Self-test: the cloud reached your phone"), CloudSync.cachedSessions(ctx))
        val c = CornerJson.read(CloudSync.cachedCorners(ctx)!!)
        assertEquals(7, c.single().id)
        // a second check finds nothing new
        val again = CloudSync(ctx, worker()).run()
        assertEquals(0, again.newSessions.size);  assertEquals(0, again.newCorners)
    }

    @Test fun aWrongPassphraseSaysSoAndKeepsTheAnswersForLater() {
        val ctx = ApplicationProvider.getApplicationContext<android.content.Context>()
        val box = Outbox(ctx.filesDir)
        box.keepFrom(box.size());  box.add("/checks/1/answer", JSONObject().put("answer", "ball"))
        val e = runCatching { CloudSync(ctx, worker("wrong")).run() }.exceptionOrNull()
        assertTrue(e is CloudError && e.code == 401)
        assertEquals(1, box.size())
    }

    @Test fun linksToAnyOtherHostAreRefused() {
        val ctx = ApplicationProvider.getApplicationContext<android.content.Context>()
        val e = runCatching { worker().download("https://evil.example.com/x.jpg", File(ctx.cacheDir, "x")) }.exceptionOrNull()
        assertTrue(e is IllegalArgumentException)
    }
}
