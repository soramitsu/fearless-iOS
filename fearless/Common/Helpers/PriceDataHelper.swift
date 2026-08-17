import Foundation
import SSFModels

struct AssetPriceKey: Hashable {
    let priceId: String
    let currencyId: String
}

/// Process-wide cache for prices whose provider and fiat currency identities
/// are both known. `AssetModel` only retains a legacy scalar price, so callers
/// must resolve through this cache instead of attaching the scalar to whichever
/// currency happens to be selected later.
final class ExactAssetPriceCache: @unchecked Sendable {
    static let shared = ExactAssetPriceCache()

    private let lock = NSLock()
    private var pricesByKey: [AssetPriceKey: PriceData] = [:]

    func price(priceId: String, currencyId: String) -> PriceData? {
        let key = AssetPriceKey(priceId: priceId, currencyId: currencyId)
        lock.lock()
        defer { lock.unlock() }
        return pricesByKey[key]
    }

    /// Merges a successful partial refresh. A new value replaces only the
    /// identical `(priceId, currencyId)` row; other currencies remain intact.
    func upsert(_ prices: [PriceData]) {
        let validPrices = prices.compactMap { price -> (AssetPriceKey, PriceData)? in
            guard let key = Self.validatedKey(for: price) else {
                return nil
            }
            return (key, price)
        }

        lock.lock()
        validPrices.forEach { pricesByKey[$0.0] = $0.1 }
        lock.unlock()
    }

    /// Compatibility spelling used by price subscription and migration paths.
    func merge(_ prices: [PriceData]) {
        upsert(prices)
    }

    /// Replaces the complete cache snapshot. Kept explicit so tests and future
    /// lifecycle owners cannot accidentally use a partial refresh as a reset.
    func replaceAll(with prices: [PriceData]) {
        let replacement = Dictionary(
            prices.compactMap { price -> (AssetPriceKey, PriceData)? in
                guard let key = Self.validatedKey(for: price) else {
                    return nil
                }
                return (key, price)
            },
            uniquingKeysWith: { _, latest in latest }
        )

        lock.lock()
        pricesByKey = replacement
        lock.unlock()
    }

    func clear() {
        lock.lock()
        pricesByKey.removeAll()
        lock.unlock()
    }

    func removeAll() {
        clear()
    }

    func price(currencyId: String, priceId: String) -> PriceData? {
        price(priceId: priceId, currencyId: currencyId)
    }

    private static func validatedKey(for price: PriceData) -> AssetPriceKey? {
        guard !price.priceId.isEmpty,
              !price.currencyId.isEmpty else {
            return nil
        }

        let normalizedPrice = price.price.trimmingCharacters(in: .whitespacesAndNewlines)
        let scanner = Scanner(string: normalizedPrice)
        scanner.locale = Locale(identifier: "en_US_POSIX")
        scanner.charactersToBeSkipped = nil
        guard !normalizedPrice.isEmpty,
              let decimalPrice = scanner.scanDecimal(),
              scanner.isAtEnd,
              !decimalPrice.isNaN,
              decimalPrice > .zero else {
            return nil
        }

        return AssetPriceKey(priceId: price.priceId, currencyId: price.currencyId)
    }
}

typealias AssetPriceCache = ExactAssetPriceCache

public extension AssetModel {
    /// Resolves only a price whose provider and fiat currency identities were
    /// preserved by the live or migrated price cache. The legacy scalar
    /// `price` has no currency provenance and must never be relabelled here.
    func getPrice(for currency: Currency) -> PriceData? {
        guard let priceId else {
            return nil
        }

        return ExactAssetPriceCache.shared.price(
            priceId: priceId,
            currencyId: currency.id
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
