package com.nvp.node.worker

import com.nvp.node.Config
import com.nvp.node.net.ApiClient
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlin.math.max

data class JobOutcome(val accepted: Boolean, val credited: Double, val balance: Double, val latencyMs: Int, val tokensPerSec: Double)

/** Drives the worker lifecycle: heartbeat + poll → infer → submit, on background dispatchers. */
class WorkerLoop(
    private val api: ApiClient,
    private val engine: InferenceEngine,
    private val onStatus: (String) -> Unit,
    private val onActivity: (String) -> Unit,
    private val onJob: (JobOutcome) -> Unit,
    private val onError: (String) -> Unit,
) {
    private var loop: Job? = null
    private var beat: Job? = null

    fun start(scope: CoroutineScope) {
        if (loop != null) return
        beat = scope.launch(Dispatchers.IO) {
            while (isActive) { api.heartbeat(); delay(20_000) }
        }
        loop = scope.launch(Dispatchers.IO) {
            onStatus("loading model…"); onActivity("loadingModel")
            runCatching { engine.load() }.onFailure { onError("load failed: ${it.message}") }
            onStatus("working")
            while (isActive) {
                if (!engine.isLoaded) { delay(1000); continue }
                onActivity("waiting")
                val job = runCatching { api.nextJob(Config.modelCaps) }.getOrNull()
                if (job == null) { delay(300); continue }
                onActivity("inferring")
                runCatching {
                    val maxTok = minOf(Config.maxTokensCap, job.maxTokens)
                    val g = engine.generate(job.prompt, maxTok, job.reasoning)
                    onActivity("submitting")
                    val tps = if (g.latencyMs > 0) g.tokensOut / (g.latencyMs / 1000.0) else 0.0
                    val r = api.submitResult(job.jobId, g.text, g.latencyMs, g.tokensOut)
                    if (r != null) onJob(JobOutcome(r.accepted, r.credited, r.balance, g.latencyMs, tps))
                }.onFailure { onError(it.message ?: "job error"); delay(1500) }
            }
        }
    }

    fun stop() {
        loop?.cancel(); beat?.cancel(); loop = null; beat = null
        engine.unload(); onStatus("idle"); onActivity("idle")
    }
}
