package io.github.wotworth.tennis.domain

import java.time.LocalDate

/** Today and now, fixed by tests so screenshots don't change with the date. */
object Now {
    @Volatile var fixedDay: Long? = null
    @Volatile var fixedMillis: Long? = null
    fun day(): Long = fixedDay ?: LocalDate.now().toEpochDay()
    fun millis(): Long = fixedMillis ?: System.currentTimeMillis()
}
