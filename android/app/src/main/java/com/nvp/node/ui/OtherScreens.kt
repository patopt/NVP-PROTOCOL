package com.nvp.node.ui

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.nvp.node.AppState
import com.nvp.node.Config
import com.nvp.node.ModelStore
import com.nvp.node.ui.theme.Nvp
import com.nvp.node.util.Logs
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.sin

@Composable private fun colScroll(content: @Composable androidx.compose.foundation.layout.ColumnScope.() -> Unit) {
    Column(Modifier.fillMaxSize().background(MaterialTheme.colorScheme.background).verticalScroll(rememberScrollState()).padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp), content = content)
}

@Composable private fun card(content: @Composable androidx.compose.foundation.layout.ColumnScope.() -> Unit) {
    Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(24.dp)) {
        Column(Modifier.fillMaxWidth().padding(18.dp), verticalArrangement = Arrangement.spacedBy(6.dp), content = content)
    }
}

@Composable private fun title(t: String) =
    Text(t, fontSize = 22.sp, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.onBackground)

@Composable
fun NetworkScreen(app: AppState, modifier: Modifier = Modifier) {
    Column(modifier) {
        colScroll {
            title("Réseau NVP")
            card {
                Text("État du réseau", fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.onSurface)
                NetworkGraph()
                Text(if (app.connected) "Connecté au coordinateur." else "Hors ligne — vérifie l'URL (Réglages).",
                    fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            card {
                Text("Mode NVP-D (distribué)", fontWeight = FontWeight.Bold, color = Nvp.tealLight)
                Text("Le worker exécute les tâches reçues du coordinateur. Le partage d'un modèle sur plusieurs appareils (shards) côté Android suivra le moteur on-device.",
                    fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
}

@Composable private fun NetworkGraph() {
    val tr = rememberInfiniteTransition(label = "net")
    val pulse by tr.animateFloat(0f, 1f, infiniteRepeatable(tween(1400), RepeatMode.Reverse), label = "p")
    Canvas(Modifier.fillMaxWidth().height(220.dp)) {
        val cx = size.width / 2; val cy = size.height / 2; val r = minOf(cx, cy) - 36f
        val n = 6
        for (i in 0 until n) {
            val a = 2 * PI * i / n - PI / 2
            val x = (cx + r * cos(a)).toFloat(); val y = (cy + r * sin(a)).toFloat()
            drawLine(Nvp.tealLight.copy(alpha = 0.2f + 0.5f * pulse), Offset(cx, cy), Offset(x, y), strokeWidth = 3f)
            drawCircle(Nvp.green, radius = 9f + 4f * pulse, center = Offset(x, y))
        }
        drawCircle(Nvp.accent.copy(alpha = 0.25f + 0.25f * pulse), radius = 40f, center = Offset(cx, cy))
        drawCircle(Nvp.accent, radius = 24f, center = Offset(cx, cy))
    }
}

@Composable
fun EarningsScreen(app: AppState, modifier: Modifier = Modifier) {
    Column(modifier) {
        colScroll {
            title("Gains")
            Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(28.dp)).background(Nvp.tealLight).padding(26.dp),
                horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text("Solde total", color = Nvp.onTeal.copy(alpha = .7f), fontSize = 13.sp)
                Text(usd(app.balance), color = Nvp.onTeal, fontSize = 44.sp, fontWeight = FontWeight.Black)
            }
            card {
                Text("Activité (7 jours)", fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.onSurface)
                BarChart(app.jobsToday)
                Text("Jobs aujourd'hui : ${app.jobsToday} · ${app.tokensPerSec.toInt()} tok/s",
                    fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
}

@Composable private fun BarChart(today: Int) {
    val data = listOf(2, 5, 3, 8, 4, 6, maxOf(today, 1))
    val maxV = (data.max()).toFloat()
    Canvas(Modifier.fillMaxWidth().height(120.dp)) {
        val n = data.size; val gap = 10f; val bw = (size.width - gap * (n - 1)) / n
        data.forEachIndexed { i, v ->
            val h = size.height * (v / maxV) * 0.9f
            val x = i * (bw + gap)
            drawRoundRect(if (i == n - 1) Nvp.accent else Nvp.tealLight,
                topLeft = Offset(x, size.height - h), size = androidx.compose.ui.geometry.Size(bw, h),
                cornerRadius = androidx.compose.ui.geometry.CornerRadius(8f, 8f))
        }
    }
}

@Composable
fun LogsScreen(modifier: Modifier = Modifier) {
    Column(modifier.fillMaxSize().background(MaterialTheme.colorScheme.background).padding(16.dp)) {
        title("Logs")
        LazyColumn(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            items(Logs.lines) { l ->
                val c = when (l.level) { "success" -> Nvp.green; "error" -> Nvp.red; "warn" -> Color(0xFFD9A441); else -> MaterialTheme.colorScheme.onSurfaceVariant }
                Text("• ${l.msg}", color = c, fontSize = 12.sp)
            }
        }
    }
}

@Composable
fun SettingsScreen(app: AppState, modifier: Modifier = Modifier) {
    var url by remember { mutableStateOf(Config.coordinatorUrl) }
    var model by remember { mutableStateOf(Config.modelId) }
    var dlUrl by remember { mutableStateOf("") }
    val picker = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        uri?.let { app.importModel(it) }
    }
    Column(modifier) {
        colScroll {
            title("Réglages")
            card {
                Text("Coordinateur", fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.onSurface)
                OutlinedTextField(url, { url = it; Config.coordinatorUrl = it.trim() }, label = { Text("URL") },
                    singleLine = true, modifier = Modifier.fillMaxWidth(), keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Uri))
                OutlinedTextField(model, { model = it; Config.modelId = it.trim() }, label = { Text("Modèle (id)") },
                    singleLine = true, modifier = Modifier.fillMaxWidth())
                Button({ app.register() }, colors = ButtonDefaults.buttonColors(containerColor = Nvp.accent, contentColor = Nvp.onAccent)) {
                    Text(if (app.registered) "Enregistré ✓ — ré-enregistrer" else "Enregistrer l'appareil", fontWeight = FontWeight.Bold)
                }
                Text(if (app.connected) "Connecté ✓" else "Non connecté", fontSize = 12.sp,
                    color = if (app.connected) Nvp.green else MaterialTheme.colorScheme.onSurfaceVariant)
            }
            card {
                Text("Modèle on-device", fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.onSurface)
                Text(if (app.modelInstalled) "Installé ✓ · ${app.modelSizeMb} Mo" else "Aucun modèle (.task / .bin) installé",
                    fontSize = 13.sp, color = if (app.modelInstalled) Nvp.green else MaterialTheme.colorScheme.onSurfaceVariant)
                if (app.downloading) {
                    LinearProgressIndicator(modifier = Modifier.fillMaxWidth())
                    Text(String.format("%.0f / %.0f Mo · %.1f Mo/s", app.dlMb, app.dlTotalMb, app.dlSpeed),
                        fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedButton({ picker.launch(arrayOf("*/*")) }) { Text("Importer (.task)") }
                }
                OutlinedTextField(dlUrl, { dlUrl = it }, label = { Text("URL directe d'un modèle .task") },
                    singleLine = true, modifier = Modifier.fillMaxWidth(), keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Uri))
                Button({ app.downloadModel(dlUrl.trim()) }, enabled = !app.downloading && dlUrl.isNotBlank(),
                    colors = ButtonDefaults.buttonColors(containerColor = Nvp.accent, contentColor = Nvp.onAccent)) {
                    Text("Télécharger le modèle", fontWeight = FontWeight.Bold)
                }
                Text("Astuce : un modèle Gemma au format MediaPipe (.task) — importez-le depuis Fichiers ou collez une URL directe.",
                    fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
}
