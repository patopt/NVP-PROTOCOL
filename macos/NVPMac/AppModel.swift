import Foundation
import Combine

/// Observable worker state + lifecycle for the macOS app.
@MainActor
final class AppModel: ObservableObject {
    private let api = APIClient()
    private let engine = MLXEngine()
    private var loopTask: Task<Void, Never>?
    private var beatTask: Task<Void, Never>?

    @Published var isWorker = false
    @Published var status = "idle"
    @Published var connected = false
    @Published var registered = Config.apiKey != nil
    @Published var balance = 0.0
    @Published var creditsToday = 0.0
    @Published var jobsToday = 0
    @Published var tokensPerSec = 0.0
    @Published var logs: [String] = []
    @Published var coordinatorURL = Config.coordinatorURL
    @Published var modelId = Config.modelId

    func log(_ m: String) { logs.insert(m, at: 0); if logs.count > 150 { logs.removeLast() } }

    func saveSettings() { Config.coordinatorURL = coordinatorURL.trimmingCharacters(in: .whitespaces); Config.modelId = modelId.trimmingCharacters(in: .whitespaces) }

    func checkConnection() { Task { connected = await api.health() } }

    func register() {
        Task {
            saveSettings()
            if let key = await api.register() { Config.apiKey = key }
            registered = Config.apiKey != nil
            connected = await api.health()
            log(registered ? "Appareil enregistré" : "Échec d'enregistrement")
        }
    }

    func setWorker(_ on: Bool) {
        isWorker = on
        if on { startLoop() } else { stopLoop() }
    }

    private func startLoop() {
        status = "loading"
        beatTask = Task { while !Task.isCancelled { await api.heartbeat(); try? await Task.sleep(nanoseconds: 20_000_000_000) } }
        loopTask = Task { [weak self] in
            guard let self else { return }
            await self.engine.load(modelId: Config.modelId) { m in Task { @MainActor in self.log(m) } }
            await MainActor.run { self.status = "working" }
            while !Task.isCancelled {
                guard await self.engine.isLoaded else { try? await Task.sleep(nanoseconds: 1_000_000_000); continue }
                guard let job = await self.api.nextJob() else { try? await Task.sleep(nanoseconds: 300_000_000); continue }
                await MainActor.run { self.status = "inferring" }
                do {
                    let g = try await self.engine.generate(prompt: job.prompt)
                    let res = await self.api.submit(jobId: job.jobId, output: g.text, latencyMs: g.latencyMs, tokensOut: g.tokensOut)
                    await MainActor.run {
                        self.status = "working"
                        if let r = res {
                            self.jobsToday += 1; self.balance = r.balance; self.creditsToday += r.credited
                            self.tokensPerSec = g.latencyMs > 0 ? Double(g.tokensOut) / (Double(g.latencyMs) / 1000.0) : 0
                            self.log(r.accepted ? "Job accepté +$\(String(format: "%.4f", r.credited))" : "Job rejeté")
                        }
                    }
                } catch {
                    await MainActor.run { self.log("Erreur job: \(error.localizedDescription)") }
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                }
            }
        }
    }

    private func stopLoop() {
        loopTask?.cancel(); beatTask?.cancel(); loopTask = nil; beatTask = nil
        Task { await engine.unload() }
        status = "idle"; log("Worker désactivé")
    }
}
