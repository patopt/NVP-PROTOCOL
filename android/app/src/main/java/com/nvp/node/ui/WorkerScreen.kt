package com.nvp.node.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.nvp.node.AppState
import com.nvp.node.ui.theme.Nvp

@Composable
fun WorkerScreen(app: AppState, modifier: Modifier = Modifier) {
    LaunchedEffect(Unit) { app.checkConnection() }
    Column(
        modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
            .verticalScroll(rememberScrollState())
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
            Text("NVP Worker", fontSize = 22.sp, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.onBackground)
            StatusPill(live = app.isWorker, text = app.status)
        }

        // Balance hero — deep teal feature card (fintech identity)
        Column(
            Modifier.fillMaxWidth().clip(RoundedCornerShape(28.dp)).background(Nvp.tealLight).padding(vertical = 26.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            Text("Solde disponible", color = Nvp.onTeal.copy(alpha = .7f), fontSize = 13.sp)
            Text(usd(app.balance), color = Nvp.onTeal, fontSize = 44.sp, fontWeight = FontWeight.Black)
            Text("+${usd(app.creditsToday)} aujourd'hui", color = Nvp.onAccent, fontSize = 13.sp, fontWeight = FontWeight.Bold,
                modifier = Modifier.clip(CircleShape).background(Nvp.accent).padding(horizontal = 12.dp, vertical = 5.dp))
        }

        // Worker toggle
        Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(24.dp)) {
            Row(Modifier.fillMaxWidth().padding(18.dp), verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Text(if (app.isWorker) "Worker activé" else "Devenir worker", fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.onSurface)
                    Text(if (app.isWorker) "Gagne pendant que l'app est ouverte" else "Gagne en exécutant de l'IA", fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                Switch(checked = app.isWorker, onCheckedChange = { app.setWorking(it) })
            }
        }

        // Connection
        Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(24.dp)) {
            Row(Modifier.fillMaxWidth().padding(16.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Dot(if (app.connected) Nvp.green else Nvp.red)
                Text(if (app.connected) "Coordinateur connecté" else "Coordinateur injoignable — voir Réglages",
                    fontSize = 13.sp, color = if (app.connected) MaterialTheme.colorScheme.onSurfaceVariant else Nvp.red)
            }
        }

        // Stats grid
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            StatTile(Modifier.weight(1f), "Jobs aujourd'hui", app.jobsToday.toString())
            StatTile(Modifier.weight(1f), "Vitesse", "${app.tokensPerSec.toInt()} tok/s")
        }
        app.lastError?.let {
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(18.dp)) {
                Text("⚠ $it", color = Nvp.red, fontSize = 12.sp, modifier = Modifier.padding(14.dp))
            }
        }
    }
}

@Composable private fun StatusPill(live: Boolean, text: String) {
    Row(Modifier.clip(CircleShape).background(MaterialTheme.colorScheme.surfaceVariant).padding(horizontal = 10.dp, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        Dot(if (live) Nvp.green else MaterialTheme.colorScheme.onSurfaceVariant)
        Text(if (live) "LIVE" else text.uppercase(), fontSize = 11.sp, fontWeight = FontWeight.Bold,
            color = if (live) Nvp.green else MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

@Composable private fun StatTile(modifier: Modifier, label: String, value: String) {
    Card(modifier, colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(20.dp)) {
        Column(Modifier.padding(16.dp)) {
            Text(value, fontSize = 22.sp, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.onSurface)
            Text(label, fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

@Composable private fun Dot(color: androidx.compose.ui.graphics.Color) {
    Column(Modifier.size(9.dp).clip(CircleShape).background(color)) {}
}

fun usd(v: Double): String = "$" + (if (v != 0.0 && kotlin.math.abs(v) < 0.01) "%.6f".format(v) else "%.2f".format(v))
