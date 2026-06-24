import Foundation
import MLX
import MLXLLM
import MLXLMCommon
import Hub

struct GenResult { let text: String; let tokensOut: Int; let latencyMs: Int }

/// On-device inference via MLX Swift on Apple Silicon Macs (same stack as iOS).
actor MLXEngine {
    private var session: ChatSession?
    private(set) var isLoaded = false
    private var loadedModel = ""

    func load(modelId: String, log: @escaping @Sendable (String) -> Void) async {
        if isLoaded && loadedModel == modelId { return }
        MLX.GPU.set(cacheLimit: 64 * 1024 * 1024)
        let repo = Config.hfRepo(for: modelId)
        log("Chargement du modèle \(repo)…")
        do {
            let cfg = ModelConfiguration(id: repo)
            let hub = HubApi(downloadBase: Config.modelsDir)
            let container = try await LLMModelFactory.shared.loadContainer(hub: hub, configuration: cfg) { _ in }
            session = ChatSession(container)
            isLoaded = true; loadedModel = modelId
            log("Modèle prêt: \(modelId)")
        } catch {
            isLoaded = false
            log("Échec du chargement: \(error.localizedDescription)")
        }
    }

    func generate(prompt: String) async throws -> GenResult {
        guard let s = session else { throw NSError(domain: "nvp", code: 1) }
        let t0 = Date()
        let text = try await s.respond(to: prompt)
        let ms = Int(Date().timeIntervalSince(t0) * 1000)
        return GenResult(text: text, tokensOut: max(1, text.count / 4), latencyMs: ms)
    }

    func unload() { session = nil; isLoaded = false; MLX.GPU.clearCache() }
}
