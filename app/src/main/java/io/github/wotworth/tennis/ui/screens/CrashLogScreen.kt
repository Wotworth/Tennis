package io.github.wotworth.tennis.ui.screens

import android.content.Intent
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import io.github.wotworth.tennis.diagnostics.CrashLog
import io.github.wotworth.tennis.ui.components.Page
import io.github.wotworth.tennis.ui.components.TextRow
import io.github.wotworth.tennis.ui.theme.LocalZpx
import io.github.wotworth.tennis.ui.theme.TennisText
import io.github.wotworth.tennis.ui.theme.TennisTokens

/** NFR-02: the crash log, newest first, with share. */
@Composable
fun CrashLogScreen(log: CrashLog) {
    val context = LocalContext.current
    val entries = remember { log.entries().reversed() }
    Page("crash log") {
        if (entries.isEmpty()) {
            TennisText("No crashes recorded.", TennisTokens.Type.listPrimary)
            return@Page
        }
        TextRow("share", "Send all ${entries.size} entries to another app", onClick = {
            val send = Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_TEXT, log.shareText())
            context.startActivity(Intent.createChooser(send, null))
        })
        entries.forEach {
            TennisText(it, TennisTokens.Type.log)
            Spacer(Modifier.height(LocalZpx.current(TennisTokens.Layout.logRowGap)))
        }
    }
}
