import Foundation

/// Delegate-based downloader for large GGUF files: fast, with real byte-level
/// progress (fraction, bytes done, total). Follows HF→CDN redirects; falls back
/// to the catalog's expected size when the server omits Content-Length.
final class GGUFDownloader: NSObject, URLSessionDownloadDelegate {
    static let shared = GGUFDownloader()

    private var onProgress: ((Double, Int64, Int64) -> Void)?
    private var expected: Int64 = 0
    private var continuation: CheckedContinuation<URL, Error>?

    private lazy var session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 60
        cfg.timeoutIntervalForResource = 3600
        return URLSession(configuration: cfg, delegate: self, delegateQueue: nil)
    }()

    /// Download `url` to a temporary file; returns its URL. `onProgress` is called
    /// on a background queue.
    func download(url: URL, expectedBytes: Int64,
                  onProgress: @escaping (Double, Int64, Int64) -> Void) async throws -> URL {
        self.onProgress = onProgress
        self.expected = expectedBytes
        return try await withCheckedThrowingContinuation { cont in
            self.continuation = cont
            let task = session.downloadTask(with: url)
            task.resume()
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        let total = totalBytesExpectedToWrite > 0 ? totalBytesExpectedToWrite : expected
        let frac = total > 0 ? Double(totalBytesWritten) / Double(total) : 0
        onProgress?(min(frac, 0.999), totalBytesWritten, total)
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        // Move out of the system tmp (which is deleted when this returns).
        let dst = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".gguf")
        do {
            try? FileManager.default.removeItem(at: dst)
            try FileManager.default.moveItem(at: location, to: dst)
            continuation?.resume(returning: dst)
        } catch {
            continuation?.resume(throwing: error)
        }
        continuation = nil
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error { continuation?.resume(throwing: error); continuation = nil }
    }
}
