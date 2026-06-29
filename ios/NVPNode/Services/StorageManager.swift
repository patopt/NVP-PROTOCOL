import Foundation

/// Storage for models + NVP shards.
///
/// By default everything lives in the app's **Documents** folder, which is exposed
/// in the iOS **Files app** (under "On My iPhone › NVP Node") because file sharing
/// is enabled. So a folder named after the app is created automatically — no
/// picker needed. Users can copy the `models/` and `nexus/` folders out via Files
/// and, after reinstalling, copy them back to avoid re-downloading.
///
/// Optionally, the user can still point to a custom folder (e.g. iCloud Drive or an
/// external drive) via a security-scoped bookmark, which then survives uninstall.
enum StorageManager {
    private static let key = "nvp_storage_bookmark"
    private static var cached: URL?

    /// A custom external folder is always "configured"; the default is Documents.
    static var hasCustomFolder: Bool { UserDefaults.standard.data(forKey: key) != nil }
    static var isConfigured: Bool { true }

    /// Base folder: the custom bookmarked folder if set, else app Documents.
    static func folderURL() -> URL? {
        if let custom = resolveBookmark() { return custom }
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }

    private static func resolveBookmark() -> URL? {
        if let c = cached { return c }
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &stale)
        else { return nil }
        _ = url.startAccessingSecurityScopedResource()
        cached = url
        return url
    }

    /// Persist a custom folder choice (+ create subfolders).
    static func setFolder(_ url: URL) throws {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let data = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        UserDefaults.standard.set(data, forKey: key)
        cached = nil
        ensureSubfolders()
    }

    static func clearCustomFolder() { UserDefaults.standard.removeObject(forKey: key); cached = nil }

    static var displayName: String {
        hasCustomFolder ? (folderURL()?.lastPathComponent ?? "Dossier") : "NVP Node (Fichiers)"
    }

    private static func ensureSubfolders() {
        for sub in ["models", "nexus"] {
            if let d = folderURL()?.appendingPathComponent(sub, isDirectory: true) {
                try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
            }
        }
    }

    /// NVP shard storage (auto-created).
    static var nexusDir: URL? {
        guard let d = folderURL()?.appendingPathComponent("nexus", isDirectory: true) else { return nil }
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    /// MLX model storage (HubApi downloadBase) — auto-created.
    static var modelsDir: URL? {
        guard let d = folderURL()?.appendingPathComponent("models", isDirectory: true) else { return nil }
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }
}
