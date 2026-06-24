package com.nvp.node

import android.content.Context
import android.content.SharedPreferences

/** App configuration persisted in SharedPreferences (mirrors the iOS Config). */
object Config {
    private lateinit var prefs: SharedPreferences
    fun init(ctx: Context) { prefs = ctx.getSharedPreferences("nvp", Context.MODE_PRIVATE) }

    const val defaultCoordinatorUrl = "https://nvp-coordinator.vercel.app"

    var coordinatorUrl: String
        get() = prefs.getString("coordinator_url", defaultCoordinatorUrl) ?: defaultCoordinatorUrl
        set(v) = prefs.edit().putString("coordinator_url", v).apply()

    var apiKey: String?
        get() = prefs.getString("api_key", null)
        set(v) = prefs.edit().putString("api_key", v).apply()

    /** Stable per-install device identifier. */
    val deviceId: String
        get() = prefs.getString("device_id", null) ?: java.util.UUID.randomUUID().toString()
            .also { prefs.edit().putString("device_id", it).apply() }

    /** Model this device advertises/runs. Kept simple for the first Android build. */
    var modelId: String
        get() = prefs.getString("model_id", "gemma3_1b") ?: "gemma3_1b"
        set(v) = prefs.edit().putString("model_id", v).apply()

    val modelCaps: List<String> get() = listOf(modelId)

    const val maxTokensCap = 2048
    const val defaultMaxTokens = 512
}
