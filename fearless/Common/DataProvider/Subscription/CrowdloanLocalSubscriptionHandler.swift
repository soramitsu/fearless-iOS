import Foundation

protocol CrowdloanLocalSubscriptionHandler {
    func handleBlockNumber(
        result: Result<BlockNumber?, Error>,
        chainId: ChainModel.Id
    )
}

extension CrowdloanLocalSubscriptionHandler {
    func handleBlockNumber(
        result _: Result<BlockNumber?, Error>,
        chainId _: ChainModel.Id
    ) {}
}
