import Foundation

protocol JsonLocalSubscriptionHandler {
    func handleCrowdloanDisplayInfo(
        result: Result<CrowdloanDisplayInfoList?, Error>,
        url: URL,
        chainId: ChainModel.Id
    )
}

extension JsonLocalSubscriptionHandler {
    func handleCrowdloanDisplayInfo(
        result _: Result<CrowdloanDisplayInfoList?, Error>,
        url _: URL,
        chainId _: ChainModel.Id
    ) {}
}
