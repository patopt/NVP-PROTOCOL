import Foundation

/// Active crypto network config for the wallet, fetched from the coordinator
/// (/api/chain). The admin toggles test ↔ mainnet; the wallet picks it up here
/// without a rebuild. Cached in UserDefaults; defaults to Base Sepolia (test).
struct ChainInfo: Codable {
    var mode: String
    var rpcUrl: String
    var chainId: Int
    var explorer: String
    var nvpContract: String
    var swapRouter: String
    var faucetURL: String
    var liveSwap: Bool

    static let testDefault = ChainInfo(
        mode: "test",
        rpcUrl: "https://sepolia.base.org",
        chainId: 84532,
        explorer: "https://sepolia.basescan.org",
        nvpContract: "0x989bad8f4124fae433ed0dfa165490ed2585fc70",
        swapRouter: "",
        faucetURL: "https://www.alchemy.com/faucets/base-sepolia",
        liveSwap: false
    )
}

enum ChainConfig {
    private static let key = "nvp_chain_info"

    /// Current config (cached, or the test default).
    static var current: ChainInfo {
        if let d = UserDefaults.standard.data(forKey: key),
           let c = try? JSONDecoder().decode(ChainInfo.self, from: d) { return c }
        return .testDefault
    }

    /// Refresh from the coordinator. Safe to call on launch / before sends.
    static func refresh() async {
        guard let url = URL(string: Config.coordinatorURL + "/api/chain") else { return }
        guard let (data, resp) = try? await URLSession.shared.data(from: url),
              let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode),
              let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        let info = ChainInfo(
            mode: (j["mode"] as? String) ?? "test",
            rpcUrl: (j["rpc_url"] as? String) ?? ChainInfo.testDefault.rpcUrl,
            chainId: (j["chain_id"] as? Int) ?? ChainInfo.testDefault.chainId,
            explorer: (j["explorer"] as? String) ?? ChainInfo.testDefault.explorer,
            nvpContract: (j["nvp_contract"] as? String) ?? "",
            swapRouter: (j["swap_router"] as? String) ?? "",
            faucetURL: (j["faucet_url"] as? String) ?? "",
            liveSwap: (j["live_swap"] as? Bool) ?? false
        )
        if let enc = try? JSONEncoder().encode(info) { UserDefaults.standard.set(enc, forKey: key) }
    }
}
