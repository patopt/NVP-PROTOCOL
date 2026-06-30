import Foundation

/// On-device web search tool for the OpenClaw runtime — no API key. DuckDuckGo
/// Lite + Instant-Answer, with a Wikipedia fallback. Mobile IPs are rarely
/// challenged, so this works directly from the device.
enum OnDeviceSearch {
    struct Result { let title: String; let url: String; let snippet: String }

    private static let ua = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"

    static func search(_ query: String, limit: Int = 5) async -> [Result] {
        for backend in [ddgLite, ddgInstant, wikipedia] {
            if let r = try? await backend(query, limit), !r.isEmpty { return Array(r.prefix(limit)) }
        }
        return []
    }

    /// Compact text block for the model.
    static func context(for query: String, limit: Int = 5) async -> String {
        let r = await search(query, limit: limit)
        if r.isEmpty { return "(aucun résultat web)" }
        return r.enumerated().map { "[\($0.offset + 1)] \($0.element.title)\n\($0.element.snippet)\n(\($0.element.url))" }.joined(separator: "\n\n")
    }

    private static func get(_ url: URL, post: String? = nil) async throws -> String {
        var req = URLRequest(url: url, timeoutInterval: 15)
        req.setValue(ua, forHTTPHeaderField: "User-Agent")
        if let post { req.httpMethod = "POST"; req.httpBody = post.data(using: .utf8); req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type") }
        let (data, _) = try await URLSession.shared.data(for: req)
        return String(data: data, encoding: .utf8) ?? ""
    }

    private static func strip(_ s: String) -> String {
        s.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&amp;", with: "&").replacingOccurrences(of: "&#x27;", with: "'")
            .replacingOccurrences(of: "&quot;", with: "\"").replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func ddgLite(_ q: String, _ limit: Int) async throws -> [Result] {
        let html = try await get(URL(string: "https://lite.duckduckgo.com/lite/")!, post: "q=" + (q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? q))
        var out: [Result] = []
        let re = try NSRegularExpression(pattern: "<a[^>]+class=\"result-link\"[^>]+href=\"([^\"]+)\"[^>]*>([\\s\\S]*?)</a>")
        let ns = html as NSString
        for m in re.matches(in: html, range: NSRange(location: 0, length: ns.length)) {
            var url = ns.substring(with: m.range(at: 1))
            if let r = url.range(of: "uddg="), let dec = String(url[r.upperBound...]).removingPercentEncoding { url = dec }
            let title = strip(ns.substring(with: m.range(at: 2)))
            if title.count > 0, url.hasPrefix("http") { out.append(Result(title: title, url: url, snippet: "")) }
            if out.count >= limit { break }
        }
        return out
    }

    private static func ddgInstant(_ q: String, _ limit: Int) async throws -> [Result] {
        let s = try await get(URL(string: "https://api.duckduckgo.com/?q=\(q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? q)&format=json&no_redirect=1&no_html=1")!)
        guard let d = s.data(using: .utf8), let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { return [] }
        var out: [Result] = []
        if let a = j["AbstractText"] as? String, !a.isEmpty, let u = j["AbstractURL"] as? String {
            out.append(Result(title: (j["Heading"] as? String) ?? q, url: u, snippet: a))
        }
        let related = (j["RelatedTopics"] as? [[String: Any]]) ?? []
        for t in related {
            if out.count >= limit { break }
            if let txt = t["Text"] as? String, let u = t["FirstURL"] as? String {
                out.append(Result(title: String(txt.prefix(60)), url: u, snippet: txt))
            }
        }
        return out
    }

    private static func wikipedia(_ q: String, _ limit: Int) async throws -> [Result] {
        let s = try await get(URL(string: "https://en.wikipedia.org/w/api.php?action=query&list=search&srsearch=\(q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? q)&format=json&srlimit=\(limit)&origin=*")!)
        guard let d = s.data(using: .utf8), let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
              let query = j["query"] as? [String: Any], let arr = query["search"] as? [[String: Any]] else { return [] }
        return arr.map { Result(title: ($0["title"] as? String) ?? "", url: "https://en.wikipedia.org/wiki/" + (($0["title"] as? String) ?? "").replacingOccurrences(of: " ", with: "_"), snippet: strip(($0["snippet"] as? String) ?? "")) }
    }
}
