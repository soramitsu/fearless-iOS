import BigInt
import Foundation
import SSFModels
import WalletCore

/// The Arbitrum USD feeds used by the shipping iOS price provider.
struct Chainlink: Decodable {
    struct Feed: Decodable { let contract: String; let decimals: Int }
    let url: URL
    let chainId: String
    let feeds: [String: Feed]
    static let source: Self? = {
        guard let resource = Bundle.module.url(forResource: "chainlink", withExtension: "json"),
              let data = try? Data(contentsOf: resource) else { return nil }
        return try? JSONDecoder().decode(Self.self, from: data)
    }()

    func price(id: String, feed: Feed, session: URLSession) async throws -> AssetPrice {
        func call(_ method: String, _ params: [Any]) async throws -> String {
            var req = URLRequest(url: url, timeoutInterval: 12)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONSerialization.data(withJSONObject: [
                "jsonrpc": "2.0",
                "id": 1,
                "method": method,
                "params": params
            ])
            let (data, response) = try await session.data(for: req)
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  object["id"] as? Int == 1,
                  let result = object["result"] as? String else { throw WalletError.network("Price feed unavailable.") }
            return result
        }
        guard let expected = UInt64(chainId),
              try await call("eth_chainId", []) == "0x" + String(expected, radix: 16) else {
            throw WalletError.network("Incorrect price-feed network.")
        }
        let hex = try await call("eth_call", [["to": feed.contract, "data": "0xfeaf968c"], "latest"])
        guard hex.hasPrefix("0x"), hex.utf8.count == 322,
              let bytes = try? Data(hexStringSSF: hex) else { throw WalletError.network("Invalid oracle response.") }
        let round = BigUInt(bytes.prefix(32)), answer = BigUInt(bytes[32 ..< 64]), updated = BigUInt(bytes[96 ..< 128])
        guard !round.isZero, BigUInt(bytes[128 ..< 160]) >= round, !answer.isZero, answer.bitWidth < 256,
              let timestamp = UInt64(exactly: updated),
              let amount = TokenAmount(units: String(answer), decimals: feed.decimals)
        else { throw WalletError.network("Invalid oracle round.") }
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        guard (0 ... 172_800).contains(Date().timeIntervalSince(date))
        else { throw WalletError.network("Stale oracle price.") }
        return AssetPrice(priceID: id, currency: .usd, value: amount.decimalValue, change24h: nil)
    }
}
