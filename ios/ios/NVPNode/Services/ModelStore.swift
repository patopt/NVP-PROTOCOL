import Foundation

/// Whether a GGUF model is downloaded on-device. Backed by LlamaEngine's local
/// GGUF storage. Sizes are the catalog's declared sizes.
enum ModelStore {
    /// Is the model downloaded and ready to load?
    static func isInstalled(_ modelId: String) -> Bool {
        LlamaEngine.isDownloaded(modelId)
    }

    /// Approx on-disk size in GB (catalog estimate when installed, else 0).
    static func sizeOnDiskGB(_ modelId: String) -> Double {
        isInstalled(modelId) ? Config.declaredMB(modelId) / 1024.0 : 0
    }
}
