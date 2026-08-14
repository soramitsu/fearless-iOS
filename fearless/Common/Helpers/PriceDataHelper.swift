import Foundation
import SSFModels

final class AssetPriceCache {
    static let shared = AssetPriceCache()

    private struct Key: Hashable {
        let currencyId: String
        let priceId: String
    }

    private let lock = NSLock()
    private var pricesByKey: [Key: PriceData] = [:]

    private init() {}

    func merge(_ prices: [PriceData]) {
        lock.lock()
        prices.forEach { price in
            let key = Key(currencyId: price.currencyId, priceId: price.priceId)
            pricesByKey[key] = price
        }
        lock.unlock()
    }

    func price(currencyId: String, priceId: String) -> PriceData? {
        lock.lock()
        defer { lock.unlock() }
        return pricesByKey[Key(currencyId: currencyId, priceId: priceId)]
    }

    func removeAll() {
        lock.lock()
        pricesByKey.removeAll(keepingCapacity: false)
        lock.unlock()
    }
}

public extension AssetModel {
    func getPrice(for currency: Currency) -> PriceData? {
        guard let priceId else {
            return nil
        }

        return AssetPriceCache.shared.price(
            currencyId: currency.id,
            priceId: priceId
        )
    }
}

enum PriceDataHelper {
    static func prices(for currency: Currency, from chainAssets: [ChainAsset]) -> [PriceData] {
        let pricesForCurrency: [PriceData] = chainAssets.compactMap { chainAsset in
            chainAsset.asset.getPrice(for: currency)
        }
        return pricesForCurrency.uniq { $0.priceId }
    }
}
