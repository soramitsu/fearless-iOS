import SSFModels

enum PriceDataHelper {
    static func prices(for currency: Currency, from chainAssets: [ChainAsset]) -> [PriceData] {
        let pricesForCurrency: [PriceData] = chainAssets.compactMap { chainAsset in
            chainAsset.asset.getPrice(for: currency)
        }
        return pricesForCurrency.uniq { $0.priceId }
    }
}
