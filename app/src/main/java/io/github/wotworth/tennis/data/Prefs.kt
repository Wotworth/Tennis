package io.github.wotworth.tennis.data

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue

/**
 * Small settings kept in SharedPreferences and mirrored in Compose state. The API key is not here
 * (PHO-22: it has its own encrypted store).
 */
class Prefs(context: Context) {
    private val sp = context.getSharedPreferences("settings", Context.MODE_PRIVATE)

    /** The racquet the strings page shows (RAC-04). */
    var selectedRacquet by mutableLongStateOf(sp.getLong("selectedRacquet", 0L))
        private set
    fun selectRacquet(id: Long) { selectedRacquet = id; sp.edit().putLong("selectedRacquet", id).apply() }

    /** RAC-05: the racquets of the last session, the default for the next one. */
    var lastRacquets by mutableStateOf(sp.getString("lastRacquets", "")!!.split(',').mapNotNull { it.toLongOrNull() })
        private set
    fun rememberLastRacquets(ids: List<Long>) { lastRacquets = ids; sp.edit().putString("lastRacquets", ids.joinToString(",")).apply() }

    /**
     * TIL-04 (v0.6): what the launcher tile shows: [TILE_OFF] (no live content: the plain racket
     * icon), [TILE_LAST] (the last-used racquet) or [TILE_FLIP] (each racquet in turn, TIL-03).
     */
    var tileMode by mutableIntStateOf(sp.getInt("tileMode", if (sp.getBoolean("tileFlips", false)) TILE_FLIP else TILE_LAST))
        private set
    fun chooseTileMode(v: Int) { tileMode = v; sp.edit().putInt("tileMode", v).apply() }
    val tileFlips: Boolean get() = tileMode == TILE_FLIP
    fun chooseTileFlips(v: Boolean) = chooseTileMode(if (v) TILE_FLIP else TILE_LAST)

    companion object {
        const val TILE_OFF = 0
        const val TILE_LAST = 1
        const val TILE_FLIP = 2
    }

    /** NAV-02: which strings page layout to show (1, 2 or 3), for Chris to choose. */
    var stringsLayout by mutableIntStateOf(sp.getInt("stringsLayout", 1))
        private set
    fun chooseStringsLayout(v: Int) { stringsLayout = v; sp.edit().putInt("stringsLayout", v).apply() }

    fun getInt(key: String, def: Int) = sp.getInt(key, def)
    fun putInt(key: String, v: Int) = sp.edit().putInt(key, v).apply()
    fun getFloat(key: String, def: Float) = sp.getFloat(key, def)
    fun putFloat(key: String, v: Float) = sp.edit().putFloat(key, v).apply()
    fun getLong(key: String, def: Long) = sp.getLong(key, def)
    fun putLong(key: String, v: Long) = sp.edit().putLong(key, v).apply()
}
