import Foundation
import CoreML
import StableDiffusion
import UniformTypeIdentifiers
import ImageIO

/// On-device image generation via Apple ml-stable-diffusion (Core ML). Downloads
/// a compiled Core ML Stable Diffusion model (split-einsum, Neural Engine) and
/// runs the pipeline locally. Returns a PNG data URI the chat can render.
actor ImageEngine {
    private var pipeline: StableDiffusionPipeline?
    private var loadedId: String?

    // The compiled resources a StableDiffusionPipeline needs in one folder.
    private static let required = ["TextEncoder.mlmodelc", "VAEDecoder.mlmodelc", "vocab.json", "merges.txt"]

    private static func baseDir() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let d = base.appendingPathComponent("sd", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }
    static func modelDir(_ id: String) -> URL { baseDir().appendingPathComponent(id, isDirectory: true) }

    static func isDownloaded(_ id: String) -> Bool {
        let dir = modelDir(id)
        let fm = FileManager.default
        guard required.allSatisfy({ fm.fileExists(atPath: dir.appendingPathComponent($0).path) }) else { return false }
        // Unet may be single or chunked.
        return fm.fileExists(atPath: dir.appendingPathComponent("Unet.mlmodelc").path)
            || fm.fileExists(atPath: dir.appendingPathComponent("UnetChunk1.mlmodelc").path)
    }

    /// Download the compiled split-einsum resources from a Hugging Face repo.
    func download(id: String, repo: String, variant: String = "split_einsum/compiled",
                  onProgress: @escaping @Sendable (Double, Int64, Int64) -> Void) async throws {
        let dir = Self.modelDir(id)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        // List repo files, keep the chosen variant subtree.
        let apiURL = URL(string: "https://huggingface.co/api/models/\(repo)?expand=siblings")!
        let (data, _) = try await URLSession.shared.data(from: apiURL)
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        let siblings = (obj["siblings"] as? [[String: Any]]) ?? []
        let prefix = variant + "/"
        let files = siblings.compactMap { $0["rfilename"] as? String }.filter { $0.hasPrefix(prefix) && !$0.hasSuffix("/") }
        guard !files.isEmpty else { throw NVPError.notLoaded }

        var done = 0
        for f in files {
            let rel = String(f.dropFirst(prefix.count)) // path under modelDir
            let dest = dir.appendingPathComponent(rel)
            try? FileManager.default.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: dest.path) { done += 1; continue }
            let src = URL(string: "https://huggingface.co/\(repo)/resolve/main/\(f)")!
            let (tmp, _) = try await URLSession.shared.download(from: src)
            try? FileManager.default.removeItem(at: dest)
            try FileManager.default.moveItem(at: tmp, to: dest)
            done += 1
            onProgress(Double(done) / Double(files.count), Int64(done), Int64(files.count))
        }
    }

    func load(id: String, repo: String, onProgress: @escaping @Sendable (Double, Int64, Int64) -> Void) async throws {
        if pipeline != nil && loadedId == id { return }
        if !Self.isDownloaded(id) { try await download(id: id, repo: repo, onProgress: onProgress) }
        onProgress(1.0, 0, 0)
        let cfg = MLModelConfiguration()
        cfg.computeUnits = .cpuAndNeuralEngine
        let p = try StableDiffusionPipeline(resourcesAt: Self.modelDir(id), controlNet: [], configuration: cfg, reduceMemory: true)
        try p.loadResources()
        pipeline = p
        loadedId = id
    }

    /// Generate one image; returns a PNG data URI string.
    func generate(prompt: String, steps: Int = 20, seed: UInt32) async throws -> String {
        guard let pipeline else { throw NVPError.notLoaded }
        var config = StableDiffusionPipeline.Configuration(prompt: prompt)
        config.stepCount = max(8, min(steps, 30))
        config.seed = seed
        config.guidanceScale = 7.5
        config.disableSafety = false
        let images = try pipeline.generateImages(configuration: config) { _ in true }
        guard let cg = images.compactMap({ $0 }).first else { throw NVPError.notLoaded }
        guard let png = Self.pngData(cg) else { throw NVPError.notLoaded }
        return "data:image/png;base64," + png.base64EncodedString()
    }

    func unload() { pipeline = nil; loadedId = nil }

    private static func pngData(_ cg: CGImage) -> Data? {
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, cg, nil)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return data as Data
    }
}
