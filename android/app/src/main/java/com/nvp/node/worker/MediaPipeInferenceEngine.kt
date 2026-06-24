package com.nvp.node.worker

import android.content.Context
import com.google.mediapipe.tasks.genai.llminference.LlmInference
import com.nvp.node.Config
import com.nvp.node.ModelStore
import com.nvp.node.util.Logs

/**
 * Real on-device inference via MediaPipe LLM Inference (Google AI Edge).
 * Loads a `.task`/`.bin` model file (e.g. a Gemma bundle) located by [ModelStore]
 * and runs greedy generation. This is the Android counterpart of the iOS MLX engine.
 */
class MediaPipeInferenceEngine(private val context: Context) : InferenceEngine {
    private var llm: LlmInference? = null
    override var isLoaded = false
        private set

    override suspend fun load() {
        val path = ModelStore.modelFilePath(context)
            ?: run { Logs.add("error", "Aucun modèle .task trouvé — importez-en un dans Réglages"); isLoaded = false; return }
        runCatching {
            val options = LlmInference.LlmInferenceOptions.builder()
                .setModelPath(path)
                .setMaxTokens(Config.maxTokensCap)
                .build()
            llm = LlmInference.createFromOptions(context, options)
            isLoaded = true
            Logs.add("success", "Modèle chargé: ${path.substringAfterLast('/')}")
        }.onFailure {
            isLoaded = false
            Logs.add("error", "Échec du chargement du modèle: ${it.message}")
        }
    }

    override suspend fun generate(prompt: String, maxTokens: Int, reasoning: Boolean): GenResult {
        val engine = llm ?: throw IllegalStateException("model not loaded")
        val t0 = System.currentTimeMillis()
        val text = engine.generateResponse(prompt)
        val ms = (System.currentTimeMillis() - t0).toInt()
        val tokens = maxOf(1, text.length / 4)
        return GenResult(text, tokens, ms)
    }

    override fun unload() {
        runCatching { llm?.close() }
        llm = null; isLoaded = false
    }
}
