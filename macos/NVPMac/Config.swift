import Foundation

/// App configuration persisted in UserDefaults (macOS worker).
enum Config {
    static var coordinatorURL: String {
        get { UserDefaults.standard.string(forKey: "coordinator_url") ?? "https://nvp-coordinator.vercel.app" }
        set { UserDefaults.standard.set(newValue, forKey: "coordinator_url") }
    }
    static var apiKey: String? {
        get { UserDefaults.standard.string(forKey: "api_key") }
        set { UserDefaults.standard.set(newValue, forKey: "api_key") }
    }
    static var modelId: String {
        get { UserDefaults.standard.string(forKey: "model_id") ?? "gemma3_1b" }
        set { UserDefaults.standard.set(newValue, forKey: "model_id") }
    }
    static var modelCaps: [String] { [modelId] }

    static var deviceId: String {
        if let v = UserDefaults.standard.string(forKey: "device_id") { return v }
        let v = "mac_" + UUID().uuidString.lowercased()
        UserDefaults.standard.set(v, forKey: "device_id")
        return v
    }

    /// HuggingFace repo backing each on-device model id (same mapping as iOS).
    static func hfRepo(for id: String) -> String {
        switch id {
        case "gemma4_e2b": return "mlx-community/gemma-4-e2b-it-4bit"
        case "gemma3n_e2b": return "mlx-community/gemma-3n-E2B-it-lm-4bit"
        case "qwen2_5_0_5b": return "mlx-community/Qwen2.5-0.5B-Instruct-4bit"
        case "phi4_mini": return "mlx-community/Phi-4-mini-instruct-4bit"
        case "llama3_2_3b": return "mlx-community/Llama-3.2-3B-Instruct-4bit"
        case "llama3_2_3b_abliterated": return "mlx-community/Llama-3.2-3B-Instruct-abliterated-6bit"
        case "nidum_llama3_2_3b": return "osmapi/Nidum-Llama-3.2-3B-Uncensored-MLX-4bit"
        default: return "mlx-community/gemma-3-1b-it-qat-4bit"
        }
    }

    static let maxTokens = 1024

    /// Model download cache directory (user Application Support, persistent).
    static var modelsDir: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let d = base.appendingPathComponent("NVPWorker/models", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }
}
