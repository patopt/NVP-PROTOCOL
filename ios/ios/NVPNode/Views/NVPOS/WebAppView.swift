import SwiftUI
import WebKit

/// Full-screen in-app browser used by NVP OS to host the *web versions* of
/// services (YouTube, Telegram Web, …) so the user never leaves the worker app
/// (which keeps the worker running). The URL bar is hidden to feel native;
/// back/forward use the native edge-swipe gesture.
struct WebAppView: UIViewRepresentable {
    let url: URL
    var onProgress: (Double) -> Void = { _ in }

    func makeCoordinator() -> Coordinator { Coordinator(onProgress) }

    func makeUIView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.allowsInlineMediaPlayback = true
        cfg.defaultWebpagePreferences.allowsContentJavaScript = true
        let web = WKWebView(frame: .zero, configuration: cfg)
        web.allowsBackForwardNavigationGestures = true
        web.scrollView.contentInsetAdjustmentBehavior = .never
        web.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
        context.coordinator.observe(web)
        web.load(URLRequest(url: url))
        return web
    }

    func updateUIView(_ web: WKWebView, context: Context) {}

    static func dismantleUIView(_ web: WKWebView, coordinator: Coordinator) {
        coordinator.stop(web)
    }

    final class Coordinator: NSObject {
        private let onProgress: (Double) -> Void
        private weak var web: WKWebView?
        init(_ onProgress: @escaping (Double) -> Void) { self.onProgress = onProgress }
        func observe(_ w: WKWebView) { web = w; w.addObserver(self, forKeyPath: "estimatedProgress", options: .new, context: nil) }
        func stop(_ w: WKWebView) { w.removeObserver(self, forKeyPath: "estimatedProgress"); w.stopLoading() }
        override func observeValue(forKeyPath keyPath: String?, of object: Any?,
                                   change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
            if keyPath == "estimatedProgress", let w = web {
                DispatchQueue.main.async { self.onProgress(w.estimatedProgress) }
            }
        }
    }
}
