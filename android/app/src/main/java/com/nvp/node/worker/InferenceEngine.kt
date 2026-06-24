package com.nvp.node.worker

/** Result of one on-device generation. */
data class GenResult(val text: String, val tokensOut: Int, val latencyMs: Int)

/**
 * On-device inference abstraction. The Android on-device LLM runtime is pluggable:
 * a production implementation would wrap MediaPipe LLM Inference, llama.cpp (JNI)
 * or ONNX Runtime Mobile to run the same small models as iOS (Gemma, Llama 3.2).
 * Until a runtime is wired, [StubInferenceEngine] lets the full worker pipeline
 * run end-to-end (registration → poll → submit) without producing real answers.
 */
interface InferenceEngine {
    val isLoaded: Boolean
    suspend fun load()
    suspend fun generate(prompt: String, maxTokens: Int, reasoning: Boolean): GenResult
    fun unload()
}

/** Placeholder engine — replace with MediaPipe/llama.cpp for real inference. */
class StubInferenceEngine : InferenceEngine {
    override var isLoaded = false; private set
    override suspend fun load() { isLoaded = true }
    override suspend fun generate(prompt: String, maxTokens: Int, reasoning: Boolean): GenResult {
        val t0 = System.currentTimeMillis()
        val out = "[NVP Android — moteur d'inférence non encore branché]"
        return GenResult(out, 8, (System.currentTimeMillis() - t0).toInt())
    }
    override fun unload() { isLoaded = false }
}
