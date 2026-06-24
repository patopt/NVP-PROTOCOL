package com.nvp.node.net

import com.nvp.node.Config
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.MediaType.Companion.toMediaType
import org.json.JSONArray
import org.json.JSONObject
import java.util.concurrent.TimeUnit

data class Job(val jobId: String, val model: String, val prompt: String, val maxTokens: Int, val reasoning: Boolean)
data class SubmitResult(val accepted: Boolean, val credited: Double, val balance: Double, val reason: String?)

/** Thin HTTP client to the coordinator (register / heartbeat / nextJob / submit). */
class ApiClient {
    private val json = "application/json".toMediaType()
    private val client = OkHttpClient.Builder()
        .connectTimeout(20, TimeUnit.SECONDS)
        .readTimeout(35, TimeUnit.SECONDS) // long-poll
        .build()

    private fun base() = Config.coordinatorUrl.trimEnd('/')
    private fun authed(b: Request.Builder): Request.Builder {
        Config.apiKey?.let { b.header("Authorization", "Bearer $it") }
        return b
    }

    /** Register the worker; returns the issued device API key (if any). */
    fun register(devicePubkey: String): String? {
        val body = JSONObject()
            .put("device_pubkey", devicePubkey)
            .put("platform", "android")
            .put("model_caps", JSONArray(Config.modelCaps))
            .toString().toRequestBody(json)
        val req = Request.Builder().url(base() + "/api/workers/register").post(body).build()
        client.newCall(req).execute().use { r ->
            if (!r.isSuccessful) return null
            val o = JSONObject(r.body?.string() ?: "{}")
            return o.optString("api_key", null) ?: o.optString("apiKey", null)
        }
    }

    fun heartbeat() {
        runCatching {
            val req = authed(Request.Builder().url(base() + "/api/me/worker")).build()
            client.newCall(req).execute().use { }
        }
    }

    fun health(): Boolean = runCatching {
        val req = Request.Builder().url(base() + "/api/health").build()
        client.newCall(req).execute().use { it.isSuccessful }
    }.getOrDefault(false)

    /** Long-poll for the next job; null on 204/no job. */
    fun nextJob(models: List<String>): Job? {
        val url = base() + "/api/jobs/next?models=" + models.joinToString(",")
        val req = authed(Request.Builder().url(url)).build()
        client.newCall(req).execute().use { r ->
            if (r.code == 204 || !r.isSuccessful) return null
            val o = JSONObject(r.body?.string() ?: "{}")
            val p = o.optJSONObject("params") ?: JSONObject()
            return Job(
                jobId = o.optString("job_id"),
                model = o.optString("model"),
                prompt = o.optString("prompt"),
                maxTokens = p.optInt("max_tokens", Config.defaultMaxTokens),
                reasoning = p.optBoolean("reasoning", false),
            )
        }
    }

    fun submitResult(jobId: String, output: String, latencyMs: Int, tokensOut: Int): SubmitResult? {
        val body = JSONObject()
            .put("output", output).put("latency_ms", latencyMs).put("tokens_out", tokensOut)
            .toString().toRequestBody(json)
        val req = authed(Request.Builder().url(base() + "/api/jobs/$jobId/result")).post(body).build()
        client.newCall(req).execute().use { r ->
            if (!r.isSuccessful) return null
            val o = JSONObject(r.body?.string() ?: "{}")
            return SubmitResult(o.optBoolean("accepted"), o.optDouble("credited", 0.0), o.optDouble("balance", 0.0), o.optString("reason", null))
        }
    }
}
