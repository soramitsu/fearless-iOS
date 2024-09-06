import Foundation
import SSFModels

protocol PriceLocalSubscriptionHandler: AnyObject {
    func handlePrices(result: Result<[PriceData], Error>, for chainAssets: [ChainAsset])
}

extension PriceLocalSubscriptionHandler {
    func handlePrice(
        result _: Result<PriceData?, Error>,
        chainAsset _: ChainAsset
    ) {}
}

extension CrowdloanLocalSubscriptionHandler {
    func handlePrice(
        result _: Result<PriceData?, Error>,
        chainAsset _: ChainAsset
    ) {}
}
