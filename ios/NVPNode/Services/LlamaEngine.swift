import Foundation

/// On-device inference via llama.cpp (GGUF), using the vendored `LLM` core
/// (llama.xcframework). Replaces MLX: mmap GGUF is memory-efficient and
/// crash-resistant, the catalog is large, and our own URLSession downloader
/// reports real byte progress (fixing the stuck-at-0 progress bar).
final class LlamaEngine: InferenceEngine {
    private var llm: LLM?
    private var loadedId: String?
    private(set) var isLoaded = false
    var progressHandler: ((Double, Int64, Int64) -> Void)?

    /// Where downloaded GGUF files live (survives across launches).
    private static func modelsDir() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("gguf", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func localURL(for id: String) -> URL {
        modelsDir().appendingPathComponent("\(id).gguf")
    }

    static func isDownloaded(_ id: String) -> Bool {
        let u = localURL(for: id)
        guard let size = try? FileManager.default.attributesOfItem(atPath: u.path)[.size] as? Int64 else { return false }
        return (size ?? 0) > 1_000_000 // a real GGUF is many MB
    }

    func load(modelDir: URL?) async throws {
        try await load(modelId: Config.effectiveModelId)
    }

    /// Load a specific GGUF model id (downloading it first if needed). Used by the
    /// worker (effective model) and by NVP Studio instances (their chosen model).
    func load(modelId id: String) async throws {
        if isLoaded && loadedId == id { return }

        let local = Self.localURL(for: id)
        if !Self.isDownloaded(id) {
            try await download(urlString: Config.ggufURL(for: id), to: local,
                               expectedBytes: Int64(Config.declaredMB(id) * 1_000_000))
        }
        progressHandler?(1.0, 0, 0)

        // Build the model-appropriate chat template + load.
        let ctx = Config.contextWindow(for: id)
        let template = Self.template(for: id)
        guard let model = LLM(from: local, template: template, maxTokenCount: Int32(min(ctx, 8192))) else {
            throw NVPError.notLoaded
        }
        llm = model
        loadedId = id
        isLoaded = true
    }

    func generate(prompt: String, maxTokens: Int, reasoning: Bool) async throws -> GenResult {
        guard let llm else { throw NVPError.notLoaded }
        // The worker is STATELESS: the coordinator sends the full context (memory +
        // conversation history) inside `prompt` for every job. The vendored LLM
        // otherwise accumulates its own chat history across calls — which would
        // bleed one user's/job's context into the next and produce nonsense. Clear
        // it before each generation so every job is isolated.
        llm.history.removeAll()
        let start = Date()
        let text = await llm.getCompletion(from: prompt)
        let ms = Int(Date().timeIntervalSince(start) * 1000)
        return GenResult(text: text, tokensOut: max(1, text.count / 4), latencyMs: ms)
    }

    func unload() {
        llm = nil
        isLoaded = false
        loadedId = nil
    }

    // MARK: - Download (delegate-based, real byte progress)

    private func download(urlString: String, to dest: URL, expectedBytes: Int64) async throws {
        guard let url = URL(string: urlString) else { throw NVPError.notLoaded }
        let tmpURL = try await GGUFDownloader.shared.download(url: url, expectedBytes: expectedBytes) { frac, done, total in
            self.progressHandler?(frac, done, total)
        }
        try? FileManager.default.removeItem(at: dest)
        try FileManager.default.moveItem(at: tmpURL, to: dest)
    }

    private static func template(for id: String) -> Template {
        let l = id.lowercased()
        if l.contains("llama") { return .llama() }
        if l.contains("gemma") { return .gemma }
        if l.contains("mistral") || l.contains("ministral") { return .mistral }
        return .chatML()
    }
}

enum NVPError: Error, LocalizedError {
    case notLoaded
    var errorDescription: String? { "Inference engine not loaded" }
}
