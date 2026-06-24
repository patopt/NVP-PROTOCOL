import Foundation

struct Job { let jobId: String; let model: String; let prompt: String; let maxTokens: Int }
struct SubmitResult { let accepted: Bool; let credited: Double; let balance: Double }

/// HTTP client to the coordinator (register / heartbeat / nextJob / submit).
final class APIClient {
    private let session: URLSession = {
        let c = URLSessionConfiguration.default
        c.timeoutIntervalForRequest = 35 // long-poll
        return URLSession(configuration: c)
    }()

    private func base() -> String { Config.coordinatorURL.hasSuffix("/") ? String(Config.coordinatorURL.dropLast()) : Config.coordinatorURL }
    private func req(_ path: String, method: String = "GET", body: [String: Any]? = nil) -> URLRequest? {
        guard let url = URL(string: base() + path) else { return nil }
        var r = URLRequest(url: url); r.httpMethod = method
        if let key = Config.apiKey { r.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization") }
        if let body { r.setValue("application/json", forHTTPHeaderField: "Content-Type"); r.httpBody = try? JSONSerialization.data(withJSONObject: body) }
        return r
    }

    func health() async -> Bool {
        guard let r = req("/api/health") else { return false }
        guard let (_, resp) = try? await session.data(for: r), let h = resp as? HTTPURLResponse else { return false }
        return (200..<300).contains(h.statusCode)
    }

    func register() async -> String? {
        guard let r = req("/api/workers/register", method: "POST", body: [
            "device_pubkey": Config.deviceId, "platform": "macos", "model_caps": Config.modelCaps,
        ]) else { return nil }
        guard let (d, resp) = try? await session.data(for: r), let h = resp as? HTTPURLResponse, (200..<300).contains(h.statusCode) else { return nil }
        let o = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any]
        return (o?["api_key"] as? String) ?? (o?["apiKey"] as? String)
    }

    func heartbeat() async { if let r = req("/api/me/worker") { _ = try? await session.data(for: r) } }

    func nextJob() async -> Job? {
        guard let r = req("/api/jobs/next?models=" + Config.modelCaps.joined(separator: ",")) else { return nil }
        guard let (d, resp) = try? await session.data(for: r), let h = resp as? HTTPURLResponse else { return nil }
        if h.statusCode == 204 || !(200..<300).contains(h.statusCode) { return nil }
        guard let o = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any] else { return nil }
        let p = o["params"] as? [String: Any]
        return Job(jobId: o["job_id"] as? String ?? "", model: o["model"] as? String ?? "",
                   prompt: o["prompt"] as? String ?? "", maxTokens: (p?["max_tokens"] as? Int) ?? Config.maxTokens)
    }

    func submit(jobId: String, output: String, latencyMs: Int, tokensOut: Int) async -> SubmitResult? {
        guard let r = req("/api/jobs/\(jobId)/result", method: "POST", body: [
            "output": output, "latency_ms": latencyMs, "tokens_out": tokensOut,
        ]) else { return nil }
        guard let (d, resp) = try? await session.data(for: r), let h = resp as? HTTPURLResponse, (200..<300).contains(h.statusCode) else { return nil }
        let o = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any] ?? [:]
        return SubmitResult(accepted: o["accepted"] as? Bool ?? false, credited: o["credited"] as? Double ?? 0, balance: o["balance"] as? Double ?? 0)
    }
}
