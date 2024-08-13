import Foundation
import SSFModels

protocol PriceLocalSubscriptionHandler: AnyObject {
    func handlePrice(
        result: Result<PriceData?, Error>,
        chainAsset: ChainAsset
    )

    func handlePrices(result: Result<[PriceData], Error>, for chainAssets: [ChainAsset])
}

extension PriceLocalSubscriptionHandler {
    func handlePrices(result _: Result<[PriceData], Error>, for chainAssets: [ChainAsset]) {}

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
