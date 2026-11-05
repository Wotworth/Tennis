package io.github.wotworth.tennis.photos

import androidx.test.ext.junit.runners.AndroidJUnit4
import io.github.wotworth.tennis.Sample
import io.github.wotworth.tennis.data.StringSpec
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import javax.crypto.KeyGenerator

/** PHO-10, PHO-20, PHO-22. */
@RunWith(AndroidJUnit4::class)
class PhotosTest {

    @Test fun luxilonAluPower() {
        val text = "ALU POWER\nLUXILON\n1.25mm 16L\nmade in Belgium\n12.2m / 40ft"
        assertEquals(StringSpec("Luxilon", "ALU Power", "16L", ""), PackageText.read(text))
    }

    @Test fun solincoHyperG() {
        val text = "SOLINCO\nHYPER-G\nco-polyester\n1.25 mm\n16L GAUGE"
        assertEquals(StringSpec("Solinco", "Hyper-G", "16L", "co-poly"), PackageText.read(text))
    }

    @Test fun babolatRpmBlastFromItsDiameter() {
        val r = PackageText.read("RPM BLAST\nBabolat\n1,25 mm\nTennis string 12m")
        assertEquals("Babolat", r.brand); assertEquals("RPM Blast", r.model); assertEquals("16L", r.gauge)
    }

    @Test fun multifilamentAndKnownModel() {
        val r = PackageText.read("Wilson\nNXT Control\n16 gauge\nmultifilament", knownModels = listOf("NXT Control"))
        assertEquals(StringSpec("Wilson", "NXT Control", "16", "multifilament"), r)
    }

    @Test fun gaugeTable() {
        assertEquals("17", PackageText.gaugeFromMm(1.20)); assertEquals("16", PackageText.gaugeFromMm(1.30)); assertEquals("15L", PackageText.gaugeFromMm(1.38))
    }

    @Test fun nothingReadable() {
        assertTrue(PackageText.read("").isBlank)
    }

    @Test fun claudeAnswerParsed() {
        assertEquals(StringSpec("Luxilon", "Alu Power", "16L", "polyester"),
            ClaudeReader.parse("""{"brand":"Luxilon","model":" Alu Power","gauge":"16L","material":"polyester"}"""))
    }

    @Test fun apiKeyRoundTripAndHint() {
        val k = KeyGenerator.getInstance("AES").apply { init(256) }.generateKey()
        val store = ApiKeyStore(Sample.app()) { k }
        assertNull(store.get())
        store.set(" sk-ant-api03-abcdefghijklmnopWXYZ ")
        assertEquals("sk-ant-api03-abcdefghijklmnopWXYZ", store.get())
        assertEquals("WXYZ", store.hint())
        // Stored encrypted: the plain key isn't in the preferences file.
        val raw = Sample.app().getSharedPreferences("secure", 0).all.values.joinToString()
        assertTrue(!raw.contains("abcdefghijklmnop"))
        store.clear(); assertNull(store.get())
    }
}
