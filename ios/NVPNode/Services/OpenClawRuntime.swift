import Foundation

/// On-device OpenClaw EXECUTOR — adapted from the architecture of
/// github.com/matiasvillaverde/think (AgentOrchestrator): a decision loop that
/// alternates model generation and tool calls until a final answer.
///
/// Instances (personality, model, memory) are created and used from the web
/// chat / NVP Studio. The DEVICE only EXECUTES: when the worker receives an
/// OpenClaw job, it runs this loop locally (llama.cpp + on-device web tool) and
/// returns the final answer. No UI in the worker app.
enum OpenClaw {
    /// Run the agent loop for one task using the worker's already-loaded engine.
    /// - personality: instance system prompt. - web: allow the web_search tool.
    static func execute(
        engine: InferenceEngine,
        prompt userPrompt: String,
        personality: String,
        web: Bool,
        maxTokens: Int,
        log: @escaping @Sendable (String) -> Void = { _ in }
    ) async -> String {
        let maxToolHops = 3
        let sys = systemPrompt(personality: personality, web: web)
        // The engine applies the model's own chat template (system/user/assistant
        // roles) around whatever we pass. So we send ONE coherent user turn:
        // instructions + the task (which already carries memory + history from the
        // coordinator). We must NOT add a manual "Assistant:" cue — that fought the
        // template and produced garbled replies. Tool results are appended as extra
        // context for the next hop.
        var context = "\(sys)\n\n\(userPrompt)"

        for hop in 0...maxToolHops {
            let gen: GenResult
            do { gen = try await engine.generate(prompt: context, maxTokens: maxTokens, reasoning: false) }
            catch { return "Erreur d'inférence: \(error.localizedDescription)" }
            let out = gen.text.trimmingCharacters(in: .whitespacesAndNewlines)

            if web, hop < maxToolHops, let query = parseToolCall(out) {
                log("web_search: \(query)")
                let results = await OnDeviceSearch.context(for: query)
                context += "\n\n[Tu as cherché « \(query) ». Résultats:]\n\(results)\n\nMaintenant réponds à la demande en utilisant ces résultats."
                continue
            }
            return stripToolNoise(out)
        }
        return ""
    }

    private static func systemPrompt(personality: String, web: Bool) -> String {
        var s = "Tu es un agent OpenClaw NVP qui s'exécute sur cet appareil. "
        if !personality.isEmpty { s += personality + " " }
        if web {
            s += "\n\nTu peux chercher sur le web. Pour lancer une recherche, écris EXACTEMENT une ligne:\nTOOL web_search: <ta requête>\npuis arrête-toi. Tu recevras [Résultat outil web]; utilise-le puis réponds. Quand tu as la réponse finale, réponds normalement (sans ligne TOOL). Cite les sources [n]."
        }
        s += "\nRéponds dans la langue de l'utilisateur, clairement."
        return s
    }

    /// Detect `TOOL web_search: <query>` in the model output.
    private static func parseToolCall(_ out: String) -> String? {
        for line in out.split(separator: "\n") {
            let l = line.trimmingCharacters(in: .whitespaces)
            if let r = l.range(of: "TOOL web_search:", options: .caseInsensitive) {
                let q = l[r.upperBound...].trimmingCharacters(in: .whitespaces)
                if !q.isEmpty { return q }
            }
        }
        return nil
    }

    private static func stripToolNoise(_ out: String) -> String {
        out.split(separator: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).lowercased().hasPrefix("tool web_search:") }
            .joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
