import BigInt
import Foundation
import WalletCore

extension NetworkServices: PriceServicing {
    func prices(for priceIDs: Set<String>, in currency: FiatCurrency) async throws -> [String: AssetPrice] {
        let prefix = currency.code + "/"
        var result: [String: AssetPrice] = [:]
        for id in priceIDs {
            if let price = priceCache[prefix + id], Date().timeIntervalSince(price.updatedAt) < 60 {
                result[id] = price
            }
        }
        let missing = priceIDs.subtracting(result.keys)
        guard !missing.isEmpty else { return result }
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.coingecko.com"
        components.path = "/api/v3/simple/price"
        components.queryItems = [URLQueryItem(name: "ids", value: missing.sorted().joined(separator: ",")),
                                 URLQueryItem(name: "vs_currencies", value: currency.code),
                                 URLQueryItem(name: "include_24hr_change", value: "true")]
        guard let url = components.url else { throw WalletError.network("Invalid price request.") }
        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) else {
                throw WalletError.network("Price feed unavailable.")
            }
            let feed = try JSONDecoder().decode([String: [String: Decimal?]].self, from: data)
            for id in missing {
                guard let value = feed[id]?[currency.code] ?? nil else { continue }
                let price = AssetPrice(
                    priceID: id,
                    currency: currency,
                    value: value,
                    change24h: feed[id]?[currency.code + "_24h_change"] ?? nil
                )
                result[id] = price
                priceCache[prefix + id] = price
            }
        } catch {
            if currency.code != "usd", result.isEmpty {
                throw WalletError.network("Price feed unavailable.")
            }
        }
        if currency.code == "usd", let source = Chainlink.source {
            let remaining = missing.subtracting(result.keys)
            let fetched = await withTaskGroup(of: (String, AssetPrice?).self) { group in
                for id in remaining {
                    guard let feed = source.feeds[id] else { continue }
                    group.addTask { (id, try? await source.price(id: id, feed: feed, session: self.session)) }
                }
                var found: [String: AssetPrice] = [:]
                for await(id, price) in group {
                    found[id] = price
                }
                return found
            }
            for (id, value) in fetched {
                result[id] = value; priceCache[prefix + id] = value
            }
        }
        if result.isEmpty {
            throw WalletError.network("No requested prices are available.")
        }
        return result
    }
}
