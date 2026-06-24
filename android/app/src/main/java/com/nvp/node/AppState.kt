package com.nvp.node

import android.app.Application
import android.net.Uri
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableDoubleStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.nvp.node.net.ApiClient
import com.nvp.node.util.Logs
import com.nvp.node.worker.MediaPipeInferenceEngine
import com.nvp.node.worker.ModelDownloader
import com.nvp.node.worker.WorkerLoop
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/** Observable app state shared by all screens (mirrors the iOS AppState). */
class AppState(app: Application) : AndroidViewModel(app) {
    private val ctx = app.applicationContext
    private val api = ApiClient()
    private val engine = MediaPipeInferenceEngine(ctx)
    private val downloader = ModelDownloader()
    private var loop: WorkerLoop? = null

    var isWorker by mutableStateOf(false); private set
    var status by mutableStateOf("idle"); private set
    var activity by mutableStateOf("idle"); private set
    var connected by mutableStateOf(false); private set
    var registered by mutableStateOf(Config.apiKey != null); private set
    var onboarded by mutableStateOf(Config.apiKey != null); private set

    var balance by mutableDoubleStateOf(0.0); private set
    var creditsToday by mutableDoubleStateOf(0.0); private set
    var jobsToday by mutableIntStateOf(0); private set
    var tokensPerSec by mutableDoubleStateOf(0.0); private set
    var lastError by mutableStateOf<String?>(null); private set

    // Model state
    var modelInstalled by mutableStateOf(ModelStore.isInstalled(ctx)); private set
    var modelSizeMb by mutableIntStateOf(ModelStore.sizeOnDiskMb(ctx).toInt()); private set
    var downloading by mutableStateOf(false); private set
    var dlMb by mutableDoubleStateOf(0.0); private set
    var dlTotalMb by mutableDoubleStateOf(0.0); private set
    var dlSpeed by mutableDoubleStateOf(0.0); private set

    fun checkConnection() { viewModelScope.launch { connected = withContext(Dispatchers.IO) { api.health() } } }

    fun register() {
        viewModelScope.launch {
            val key = withContext(Dispatchers.IO) { runCatching { api.register(Config.deviceId) }.getOrNull() }
            if (key != null) Config.apiKey = key
            registered = Config.apiKey != null
            onboarded = onboarded || registered
            connected = withContext(Dispatchers.IO) { api.health() }
            Logs.add(if (registered) "success" else "warn", if (registered) "Appareil enregistré" else "Échec d'enregistrement")
        }
    }

    fun finishOnboarding() { onboarded = true }

    fun importModel(uri: Uri) {
        viewModelScope.launch {
            val ok = withContext(Dispatchers.IO) { ModelStore.importFrom(ctx, uri) }
            refreshModel()
            Logs.add(if (ok) "success" else "error", if (ok) "Modèle importé" else "Import échoué")
        }
    }

    fun downloadModel(url: String) {
        if (url.isBlank() || downloading) return
        viewModelScope.launch {
            downloading = true; dlMb = 0.0; dlTotalMb = 0.0; dlSpeed = 0.0
            Logs.add("info", "Téléchargement du modèle…")
            val ok = withContext(Dispatchers.IO) {
                downloader.download(ctx, url) { done, total, mbps ->
                    dlMb = done / 1_000_000.0; dlTotalMb = total / 1_000_000.0; dlSpeed = mbps
                }
            }
            downloading = false; refreshModel()
            Logs.add(if (ok) "success" else "error", if (ok) "Modèle téléchargé" else "Téléchargement échoué")
        }
    }

    private fun refreshModel() {
        modelInstalled = ModelStore.isInstalled(ctx); modelSizeMb = ModelStore.sizeOnDiskMb(ctx).toInt()
    }

    fun setWorking(on: Boolean) {
        isWorker = on
        if (on) {
            val l = WorkerLoop(api, engine,
                onStatus = { status = it }, onActivity = { activity = it },
                onJob = { o -> jobsToday += 1; balance = o.balance; creditsToday += o.credited; tokensPerSec = o.tokensPerSec },
                onError = { lastError = it; Logs.add("error", it) })
            loop = l; l.start(viewModelScope)
            Logs.add("info", "Worker activé")
        } else { loop?.stop(); loop = null; Logs.add("info", "Worker désactivé") }
    }
}
