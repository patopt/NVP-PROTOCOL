package com.nvp.node.ui

import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Bolt
import androidx.compose.material.icons.filled.Hub
import androidx.compose.material.icons.filled.MonetizationOn
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Article
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import com.nvp.node.AppState

private data class Tab(val label: String, val icon: ImageVector)

@Composable
fun RootScaffold(app: AppState) {
    if (!app.onboarded) { OnboardingScreen(app); return }
    var tab by remember { mutableIntStateOf(0) }
    val tabs = listOf(
        Tab("Worker", Icons.Filled.Bolt),
        Tab("Réseau", Icons.Filled.Hub),
        Tab("Gains", Icons.Filled.MonetizationOn),
        Tab("Logs", Icons.Filled.Article),
        Tab("Réglages", Icons.Filled.Settings),
    )
    Scaffold(
        bottomBar = {
            NavigationBar {
                tabs.forEachIndexed { i, t ->
                    NavigationBarItem(
                        selected = tab == i,
                        onClick = { tab = i },
                        icon = { Icon(t.icon, contentDescription = t.label) },
                        label = { Text(t.label) },
                    )
                }
            }
        }
    ) { pad ->
        val m = Modifier.padding(pad)
        when (tab) {
            0 -> WorkerScreen(app, m)
            1 -> NetworkScreen(app, m)
            2 -> EarningsScreen(app, m)
            3 -> LogsScreen(m)
            else -> SettingsScreen(app, m)
        }
    }
}
