package io.github.wotworth.tennis.ui.theme

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.luminance
import androidx.compose.ui.graphics.toArgb
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/** VIS-03, VIS-04: contrast rules for the tennis colors. */
class ColorsTest {

    private fun contrast(a: Color, b: Color): Double {
        val (hi, lo) = listOf(a.luminance().toDouble(), b.luminance().toDouble()).sortedDescending()
        return (hi + 0.05) / (lo + 0.05)
    }

    @Test fun titleGradientReadsOnBlack() {
        val c = TennisTokens.Colors
        for (stop in listOf(c.titleGradientStart, c.titleGradientEnd)) {
            val r = contrast(stop, c.background)
            assertTrue("gradient stop ${Integer.toHexString(stop.toArgb())} is $r:1 on black", r >= 4.5)
        }
    }

    @Test fun whiteReadsOnTiles() {
        val r = contrast(TennisTokens.Colors.primary, TennisTokens.Colors.tile)
        assertTrue("white on the tile green is $r:1", r >= 4.5)
    }

    @Test fun iconBackgroundMatchesTileColor() {
        val xml = File("src/main/res/values/colors.xml").readText()
        val hex = Regex("""name="tile">#([0-9A-Fa-f]{8})<""").find(xml)!!.groupValues[1]
        assertEquals(TennisTokens.Colors.tile.toArgb(), hex.toLong(16).toInt())
    }

    @Test fun strokeColoursReadOnBlack() {
        for ((stroke, c) in TennisTokens.Colors.strokes + ("other" to TennisTokens.Colors.strokeOther)) {
            val r = contrast(c, TennisTokens.Colors.background)
            assertTrue("$stroke is $r:1 on black", r >= 4.5)
        }
    }

    @Test fun strokeColoursAreDistinctAndCaseInsensitive() {
        assertEquals(TennisTokens.Colors.strokes.size, TennisTokens.Colors.strokes.values.toSet().size)
        assertEquals(TennisTokens.Colors.strokes.getValue("gameplay"), TennisTokens.Colors.stroke(" Gameplay "))
        assertEquals(TennisTokens.Colors.strokeOther, TennisTokens.Colors.stroke("drop shot"))
    }

    @Test fun strokeColoursReadOnTheTile() {
        for ((stroke, c) in TennisTokens.Colors.strokesOnTile + ("other" to TennisTokens.Colors.strokeOtherOnTile)) {
            val r = contrast(c, TennisTokens.Colors.tile)
            assertTrue("$stroke on the tile is $r:1", r >= 3.0)
        }
        assertEquals(TennisTokens.Colors.strokes.keys, TennisTokens.Colors.strokesOnTile.keys)
    }
}
