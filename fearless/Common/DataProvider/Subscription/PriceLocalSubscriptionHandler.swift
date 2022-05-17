import Foundation

protocol PriceLocalSubscriptionHandler {
    func handlePrice(
        result: Result<PriceData?, Error>,
        priceId: AssetModel.PriceId
    )
}

extension CrowdloanLocalSubscriptionHandler {
    func handlePrice(
        result _: Result<PriceData?, Error>,
        priceId _: AssetModel.PriceId
    ) {}
}
