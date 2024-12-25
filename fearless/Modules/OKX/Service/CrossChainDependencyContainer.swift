import SSFModels

final class CrossChainDependencyContainer {
    private let okxService: OKXDexAggregatorService
    private let wallet: MetaAccountModel

    init(
        okxService: OKXDexAggregatorService,
        wallet: MetaAccountModel
    ) {
        self.okxService = okxService
        self.wallet = wallet
    }

    func getOkxDataFetcher(for okxCase: OKXCase) throws -> OKXDataFetching {
        switch okxCase {
        case let .swap(chainAsset):
            let eth = try EthereumNodeFetching().getHttps(for: chainAsset.chain)
            let ethereumService = BaseEthereumService(ws: eth)
            return OKXSwapsDataFetching(okxService: okxService, wallet: wallet, ethereumService: ethereumService)
        case .bridge:
            return OKXCrossChainDataFetching(
                okxService: okxService,
                wallet: wallet
            )
        }
    }
}
