import Foundation

struct JobOutcome {
    let accepted: Bool
    let credited: Double
    let balance: Double
    let latencyMs: Int
    let tokensPerSec: Double
}

/// Live worker phase, for the animated network/activity view.
enum WorkerActivity: String, Sendable {
    case idle
    case loadingModel
    case waiting
    case receivedJob
    case inferring
    case submitting
}

/// Drives the worker lifecycle with a small local **job queue**: a producer
/// long-polls the coordinator and pre-fetches up to `maxQueue` jobs while a single
/// consumer runs inference back-to-back (the GPU is single-threaded, so we keep it
/// busy rather than running jobs in parallel). This lets one device accept more
/// requests without going idle between them, and exposes queue depth + speed.
actor WorkerLoop {
    private let api: APIClient
    private let engine: InferenceEngine
    /// Resolved each poll (NOT captured once) so switching the on-device model
    /// mid-session immediately changes what we advertise/claim — otherwise the
    /// worker keeps polling the model selected when it was first turned on.
    private let models: @Sendable () -> [String]
    private let maxQueue = Config.maxQueueDepth
    /// On-device Stable Diffusion engine (used when serving an image model).
    private let imageEngine = ImageEngine()

    private var pending: [Job] = []
    private var producer: Task<Void, Never>?
    private var consumer: Task<Void, Never>?

    init(api: APIClient, engine: InferenceEngine, models: @escaping @Sendable () -> [String]) {
        self.api = api
        self.engine = engine
        self.models = models
    }

    private func enqueue(_ job: Job) { pending.append(job) }
    private func dequeue() -> Job? { pending.isEmpty ? nil : pending.removeFirst() }
    private var queueDepth: Int { pending.count }

    /// - shouldRun: evaluated each iteration (foreground + thermal ok).
    /// - onStatus: lifecycle/status updates for the UI (e.g. "Loading model…").
    /// - onQueue: current local queue depth (jobs waiting to be processed).
    /// - onJob: called after each processed job with the outcome.
    /// - onError: called on transient errors (kept non-fatal).
    func start(
        shouldRun: @escaping @Sendable () async -> Bool,
        onStatus: @escaping @Sendable (String) async -> Void,
        onActivity: @escaping @Sendable (WorkerActivity) async -> Void,
        onQueue: @escaping @Sendable (Int) async -> Void,
        onJob: @escaping @Sendable (JobOutcome) async -> Void,
        onError: @escaping @Sendable (String) async -> Void
    ) {
        guard producer == nil, consumer == nil else { return }
        producer = Task { await self.runProducer(shouldRun: shouldRun, onQueue: onQueue, onError: onError) }
        consumer = Task {
            await self.runConsumer(
                shouldRun: shouldRun, onStatus: onStatus, onActivity: onActivity,
                onQueue: onQueue, onJob: onJob, onError: onError
            )
        }
    }

    /// Pre-fetches jobs into the local queue (only once the model is loaded, so we
    /// never claim work we can't yet run).
    private func runProducer(
        shouldRun: @escaping @Sendable () async -> Bool,
        onQueue: @escaping @Sendable (Int) async -> Void,
        onError: @escaping @Sendable (String) async -> Void
    ) async {
        var lastGate = ""
        var polledOnce = false
        while !Task.isCancelled {
            let run = await shouldRun()
            // The chat LLM must be loaded before we claim work; image jobs (Stable
            // Diffusion) load their own engine lazily on the first image job.
            let loaded = engine.isLoaded
            if !run || !loaded || pending.count >= maxQueue {
                // Surface WHY we're not pulling jobs (once per state change), so a
                // stuck worker is diagnosable from the in-app logs.
                let gate = !run ? "app en pause (arrière-plan/surchauffe)"
                    : !loaded ? "modèle pas encore chargé"
                    : "file pleine"
                if gate != lastGate { nvpLog(.warn, "En attente — \(gate)"); lastGate = gate }
                try? await Task.sleep(nanoseconds: 300_000_000)
                continue
            }
            if lastGate != "" || !polledOnce {
                nvpLog(.success, "Recherche de jobs pour \(models().joined(separator: ", "))…")
                lastGate = ""; polledOnce = true
            }
            do {
                if let job = try await api.nextJob(models: models()) {
                    enqueue(job)
                    await onQueue(queueDepth)
                    nvpLog(.info, "Job \(job.jobId) queued (\(job.model)) · depth \(queueDepth)")
                }
            } catch is CancellationError {
                return
            } catch {
                nvpLog(.error, "Échec du poll de jobs: \(error.localizedDescription)")
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    /// Loads the model, then drains the queue: infer → submit, back-to-back.
    private func runConsumer(
        shouldRun: @escaping @Sendable () async -> Bool,
        onStatus: @escaping @Sendable (String) async -> Void,
        onActivity: @escaping @Sendable (WorkerActivity) async -> Void,
        onQueue: @escaping @Sendable (Int) async -> Void,
        onJob: @escaping @Sendable (JobOutcome) async -> Void,
        onError: @escaping @Sendable (String) async -> Void
    ) async {
        while !Task.isCancelled {
            if await !shouldRun() {
                await onActivity(.idle)
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                continue
            }

            // The worker ALWAYS runs the chat LLM (text). When image generation is
            // enabled it ALSO serves the image model — decided per job below, so a
            // single worker can do both, kept as two separate engines.

            // Lazy-load the TEXT model (GGUF). Image models load in the job block.
            if !engine.isLoaded {
                do {
                    await onActivity(.loadingModel)
                    await onStatus("Loading model…")
                    nvpLog(.info, "Loading on-device model…")
                    try await engine.load(modelDir: nil)
                    await onStatus("working")
                    nvpLog(.success, "Model loaded — ready to work")
                } catch is CancellationError {
                    return
                } catch {
                    await onError("Model load failed: \(error.localizedDescription)")
                    nvpLog(.error, "Model load failed: \(error.localizedDescription)")
                    try? await Task.sleep(nanoseconds: 5_000_000_000)
                    continue
                }
            }

            guard let job = dequeue() else {
                await onActivity(.waiting)
                try? await Task.sleep(nanoseconds: 200_000_000)
                continue
            }
            await onQueue(queueDepth)
            await onActivity(.receivedJob)

            do {
                let maxTokens = min(Config.maxTokensCap, job.params?.maxTokens ?? Config.defaultMaxTokens)
                let reasoning = job.params?.reasoning ?? false
                await onActivity(.inferring)
                let t0 = Date()
                let output: String
                let isImageJob = job.params?.imagegen == true || Config.isImageModel(job.model)
                if isImageJob {
                    // Image generation ON THIS DEVICE (Core ML Stable Diffusion),
                    // a separate engine from the chat LLM.
                    let mid = Config.isImageModel(job.model) ? job.model : Config.effectiveImageModelId
                    nvpLog(.info, "🎨 Image generation task — running on-device (\(mid))")
                    await onStatus("Loading image model…")
                    try await imageEngine.load(id: mid, repo: Config.imageRepo(for: mid)) { frac, _, _ in
                        Task { await onStatus(String(format: "Image model %.0f%%", frac * 100)) }
                    }
                    await onStatus("Generating image…")
                    let seed = UInt32(truncatingIfNeeded: abs(job.prompt.hashValue) ^ Int(Date().timeIntervalSince1970))
                    output = try await imageEngine.generate(prompt: job.prompt, steps: 20, seed: seed)
                } else if job.params?.openclaw == true {
                    // NVP Studio instance → run the OpenClaw agent loop ON THIS DEVICE
                    // (tool-calling + on-device web search), return the final answer.
                    let instanceName = (job.params?.instance?.isEmpty == false) ? job.params!.instance! : "OpenClaw"
                    nvpLog(.info, "🦅 OpenClaw instance « \(instanceName) » — running on-device")
                    await onStatus("Running OpenClaw · \(instanceName)")
                    output = await OpenClaw.execute(
                        engine: engine,
                        prompt: job.prompt,
                        personality: job.params?.personality ?? "",
                        web: job.params?.web ?? false,
                        maxTokens: maxTokens,
                        log: { nvpLog(.info, "OpenClaw tool: \($0)") }
                    )
                } else {
                    let gen = try await engine.generate(prompt: job.prompt, maxTokens: maxTokens, reasoning: reasoning)
                    output = gen.text
                }
                let ms = Int(Date().timeIntervalSince(t0) * 1000)
                // Image output is a big base64 data URI — don't bill it per-token.
                let tokensOut = isImageJob ? 1 : max(1, output.count / 4)
                let tps = ms > 0 ? Double(tokensOut) / (Double(ms) / 1000.0) : 0
                nvpLog(.info, String(format: "Inferred %d tok in %d ms (%.1f tok/s)", tokensOut, ms, tps))
                await onActivity(.submitting)
                let res = try await api.submitResult(
                    jobId: job.jobId,
                    output: output,
                    latencyMs: ms,
                    tokensOut: tokensOut
                )
                if res.accepted {
                    nvpLog(.success, "Accepted +$\(String(format: "%.6f", res.credited)) · bal $\(String(format: "%.4f", res.balance))")
                } else {
                    nvpLog(.warn, "Rejected: \(res.reason ?? "verification failed")")
                }
                await onJob(JobOutcome(
                    accepted: res.accepted,
                    credited: res.credited,
                    balance: res.balance,
                    latencyMs: ms,
                    tokensPerSec: tps
                ))
            } catch is CancellationError {
                return
            } catch {
                await onError(error.localizedDescription)
                nvpLog(.error, error.localizedDescription)
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
    }

    func stop() {
        producer?.cancel()
        consumer?.cancel()
        producer = nil
        consumer = nil
        pending.removeAll()
        engine.unload()
    }
}
