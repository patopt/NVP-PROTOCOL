import Foundation

/// App configuration. The coordinator URL is user-editable (Settings) and stored
/// in UserDefaults so testers can point the app at their own deployment.
enum Config {
    private static let coordinatorKey = "coordinator_url"

    /// Default coordinator URL. Override in Settings, or set a real deployment here.
    static let defaultCoordinatorURL = "https://nvp-coordinator.vercel.app"

    static var coordinatorURL: String {
        get { UserDefaults.standard.string(forKey: coordinatorKey) ?? defaultCoordinatorURL }
        set { UserDefaults.standard.set(newValue, forKey: coordinatorKey) }
    }

    private static let modelKey = "worker_model_id"

    /// User selection: a concrete GGUF model id, or "auto" (pick by device RAM).
    static var workerModelId: String {
        get { UserDefaults.standard.string(forKey: modelKey) ?? "auto" }
        set { UserDefaults.standard.set(newValue, forKey: modelKey) }
    }

    /// The concrete model actually loaded/advertised (resolves "auto" by RAM).
    /// GGUF models load via llama.cpp (mmap) so they're crash-resistant; auto
    /// stays on a small model and bigger ones are opt-in.
    static var effectiveModelId: String {
        if workerModelId != "auto", catalog.contains(where: { $0.id == workerModelId }) {
            return workerModelId
        }
        let gb = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824.0
        // Bigger phones can default to the 3B; everyone else gets the light 1B.
        return gb >= 7.5 ? "nvp_llama_3_2_3b_q4_k_m" : "nvp_llama_3_2_1b_q4_k_m"
    }

    /// Image generation is an ADDITIVE capability: when ON, the worker keeps
    /// running its chat LLM **and** also serves the image model (Stable
    /// Diffusion), kept as two separate engines. It is NOT a replacement for the
    /// text model.
    private static let imageGenKey = "image_gen_enabled"
    static var imageGenEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: imageGenKey) }
        set { UserDefaults.standard.set(newValue, forKey: imageGenKey) }
    }
    static let defaultImageModelId = "nvp_sd_2_1_base"
    static var imageModelId: String {
        get { UserDefaults.standard.string(forKey: "image_model_id") ?? defaultImageModelId }
        set { UserDefaults.standard.set(newValue, forKey: "image_model_id") }
    }
    /// The image model this worker advertises/serves.
    static var effectiveImageModelId: String { imageModelId }

    /// What this worker advertises to the coordinator: always the chat LLM, plus
    /// the image model when image generation is enabled (two separate engines).
    static var modelCaps: [String] {
        var caps = [effectiveModelId]
        if imageGenEnabled { caps.append(effectiveImageModelId) }
        return caps
    }

    // MARK: - GGUF model catalog (llama.cpp). URLs are public Hugging Face GGUFs.
    struct GGUF: Identifiable {
        let id: String, name: String, url: String
        let mb: Double, ctx: Int
        init(_ id: String, _ name: String, _ url: String, _ mb: Double, _ ctx: Int) {
            self.id = id; self.name = name; self.url = url; self.mb = mb; self.ctx = ctx
        }
    }
    static let catalog: [GGUF] = [
        GGUF("nvp_llama_3_2_1b_q4_k_m", "Llama-3.2 1B (Q4_K_M)", "https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q4_K_M.gguf?download=true", 808, 32768),
        GGUF("nvp_llama_3_2_3b_q4_k_m", "Llama-3.2 3B (Q4_K_M)", "https://huggingface.co/bartowski/Llama-3.2-3B-Instruct-GGUF/resolve/main/Llama-3.2-3B-Instruct-Q4_K_M.gguf?download=true", 2020, 32768),
        GGUF("nvp_lfm_2_5_1_2b_instruct_q4_k_m", "LFM-2.5 1.2B Instruct (Q4_K_M)", "https://huggingface.co/LiquidAI/LFM2.5-1.2B-Instruct-GGUF/resolve/main/LFM2.5-1.2B-Instruct-Q4_K_M.gguf?download=true", 731, 32768),
        GGUF("nvp_granite_4_1_3b_q4_k_xl", "Granite 4.1 3B (Q4_K_XL)", "https://huggingface.co/unsloth/granite-4.1-3b-GGUF/resolve/main/granite-4.1-3b-UD-Q4_K_XL.gguf?download=true", 2152, 8192),
        GGUF("nvp_phi_4_mini_q4_k_m", "Phi-4 Mini (Q4_K_M)", "https://huggingface.co/unsloth/Phi-4-mini-instruct-GGUF/resolve/main/Phi-4-mini-instruct-Q4_K_M.gguf?download=true", 2492, 4096),
    ]
    private static func entry(_ id: String) -> GGUF? { catalog.first { $0.id == id } }

    // MARK: - Image generation models (Core ML Stable Diffusion, on-device).
    struct ImageModel: Identifiable { let id: String, name: String, repo: String; let mb: Double }
    static let imageCatalog: [ImageModel] = [
        ImageModel(id: "nvp_sd_2_1_base", name: "Stable Diffusion 2.1 base", repo: "apple/coreml-stable-diffusion-2-1-base", mb: 1600),
    ]
    static func isImageModel(_ id: String) -> Bool { imageCatalog.contains { $0.id == id } }
    static func imageRepo(for id: String) -> String { imageCatalog.first { $0.id == id }?.repo ?? "" }

    /// GGUF download URL for a model id.
    static func ggufURL(for id: String) -> String { entry(id)?.url ?? catalog[0].url }
    /// Context window for a model id.
    static func contextWindow(for id: String) -> Int { entry(id)?.ctx ?? 8192 }
    /// Human-friendly name for a model id.
    static func displayName(for id: String) -> String {
        entry(id)?.name ?? imageCatalog.first { $0.id == id }?.name ?? id
    }
    /// Models runnable on-device (text GGUF + image + auto).
    static var supportedOnDevice: Set<String> { Set(catalog.map { $0.id } + imageCatalog.map { $0.id } + ["auto"]) }

    /// Approx download size (MB) per model — for the progress display.
    static func declaredMB(_ id: String) -> Double {
        entry(id)?.mb ?? imageCatalog.first { $0.id == id }?.mb ?? 900
    }

    /// User opted into the Wallet (Beta) — only effective if the admin allows it.
    static var walletBetaActive: Bool {
        get { UserDefaults.standard.bool(forKey: "wallet_beta_active") }
        set { UserDefaults.standard.set(newValue, forKey: "wallet_beta_active") }
    }

    /// NVP Beta (distributed compute): when ON, this device joins the network to
    /// run a *share* of bigger models split across devices (pipeline), instead of
    /// only running whole models locally. Announces its capability to the
    /// coordinator's signaling registry.
    static var nvpBetaEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "nvp_beta_enabled") }
        set { UserDefaults.standard.set(newValue, forKey: "nvp_beta_enabled") }
    }

    /// Stable per-install peer id for the distributed network.
    static var peerId: String {
        if let p = UserDefaults.standard.string(forKey: "nvp_peer_id") { return p }
        let p = "peer_" + UUID().uuidString.lowercased().replacingOccurrences(of: "-", with: "").prefix(20)
        UserDefaults.standard.set(p, forKey: "nvp_peer_id")
        return p
    }

    /// Rough RAM (GB) available to the app — used to size the shard this device
    /// can run in NVP Beta.
    static var deviceRamGB: Double {
        Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824.0
    }

    /// Models shipped inside the IPA — none for GGUF (downloaded on-device).
    static let bundledModelIds: Set<String> = []

    /// Max tokens the worker will generate for one job (raised for longer chats). Higher = longer answers /
    /// agent steps; the engine 8-bit quantizes + caps the KV cache to stay bounded.
    static let maxTokensCap = 8192
    /// Default when a job doesn't specify one.
    static let defaultMaxTokens = 4096
    /// How many jobs the worker pre-fetches into its local queue.
    static let maxQueueDepth = 6

    // MARK: - NVP crypto — active network comes from the coordinator (admin can
    // switch test ↔ mainnet); see ChainConfig. These read the live config.
    static var chainRpcUrl: String { ChainConfig.current.rpcUrl }
    static var chainId: Int { ChainConfig.current.chainId }
    static var nvpContractAddress: String { ChainConfig.current.nvpContract }
    static var chainExplorer: String { ChainConfig.current.explorer }
    static var faucetURL: String { ChainConfig.current.faucetURL.isEmpty ? "https://www.alchemy.com/faucets/base-sepolia" : ChainConfig.current.faucetURL }
}
