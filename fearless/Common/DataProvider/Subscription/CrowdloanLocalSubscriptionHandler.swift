import Foundation

protocol CrowdloanLocalSubscriptionHandler {
    func handleBlockNumber(
        result: Result<BlockNumber?, Error>,
        chainId: ChainModel.Id
    )

    func handleCrowdloanFunds(
        result: Result<CrowdloanFunds?, Error>,
        for paraId: ParaId,
        chainId: ChainModel.Id
    )
}

extension CrowdloanLocalSubscriptionHandler {
    func handleBlockNumber(
        result _: Result<BlockNumber?, Error>,
        chainId _: ChainModel.Id
    ) {}

    func handleCrowdloanFunds(
        result _: Result<CrowdloanFunds?, Error>,
        for _: ParaId,
        chainId _: ChainModel.Id
    ) {}
}
