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
