import Foundation
import SSFModels

protocol PriceLocalSubscriptionHandler {
    func handlePrice(
        result: Result<PriceData?, Error>,
        priceId: AssetModel.PriceId
    )

    func handlePrices(result: Result<[PriceData], Error>)
}

extension PriceLocalSubscriptionHandler {
    func handlePrice(
        result _: Result<PriceData?, Error>,
        priceId _: AssetModel.PriceId
    ) {}

    func handlePrices(result _: Result<[PriceData], Error>) {}
}

extension CrowdloanLocalSubscriptionHandler {
    func handlePrice(
        result _: Result<PriceData?, Error>,
        priceId _: AssetModel.PriceId
    ) {}
}
