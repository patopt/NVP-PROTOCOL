package com.nvp.node.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.nvp.node.AppState
import com.nvp.node.Config
import com.nvp.node.ui.theme.Nvp

@Composable
fun OnboardingScreen(app: AppState) {
    var url by remember { mutableStateOf(Config.coordinatorUrl) }
    Column(
        Modifier.fillMaxSize().background(Nvp.tealLight).padding(24.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text("NVP", color = Nvp.accent, fontSize = 40.sp, fontWeight = FontWeight.Black)
        Text("Worker", color = Nvp.onTeal, fontSize = 28.sp, fontWeight = FontWeight.Bold)
        Text("Gagnez en exécutant de l'IA sur votre appareil.", color = Nvp.onTeal.copy(alpha = .8f), fontSize = 14.sp,
            modifier = Modifier.padding(vertical = 16.dp))
        OutlinedTextField(
            value = url, onValueChange = { url = it },
            label = { Text("URL du coordinateur", color = Nvp.onTeal.copy(alpha = .7f)) },
            singleLine = true, modifier = Modifier.fillMaxWidth(),
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Uri),
        )
        Button(
            onClick = { Config.coordinatorUrl = url.trim(); app.register() },
            colors = ButtonDefaults.buttonColors(containerColor = Nvp.accent, contentColor = Nvp.onAccent),
            shape = RoundedCornerShape(14.dp),
            modifier = Modifier.fillMaxWidth().padding(top = 14.dp),
        ) { Text("Rejoindre le réseau", fontWeight = FontWeight.Bold) }
        OutlinedButton(onClick = { app.finishOnboarding() }, modifier = Modifier.padding(top = 8.dp)) {
            Text("Explorer d'abord", color = Nvp.onTeal)
        }
        if (app.registered) Text("Connecté ✓", color = Nvp.accent, modifier = Modifier.padding(top = 10.dp))
    }
}
