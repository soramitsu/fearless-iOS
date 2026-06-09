import Foundation
import SSFModels
@testable import fearless

final class PriceProviderFactoryStub: PriceProviderFactoryProtocol {
    let prices: [PriceData]

    init(prices: [PriceData] = []) {
        self.prices = prices
    }

    convenience init(priceData: PriceData?) {
        self.init(prices: priceData.map { [$0] } ?? [])
    }

    func getPricesProvider(
        currencies _: [Currency]?,
        chainAssets _: [ChainAsset]
    ) -> AnySingleValueProvider<[PriceData]> {
        let provider = SingleValueProviderStub(item: prices)
        return AnySingleValueProvider(provider)
    }
}
