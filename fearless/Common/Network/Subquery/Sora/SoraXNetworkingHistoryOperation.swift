import RobinHood
import XNetworking

final class SoraXNetworkingHistoryOperation<ResultType>: BaseOperation<ResultType> {
    private let httpProvider: SoramitsuHttpClientProviderImpl
    private let soraNetworkClient: SoramitsuNetworkClient
    private let subQueryClient: SubQueryClientForSoraWallet
    private let filters: [WalletTransactionHistoryFilter]
    private let chainAsset: ChainAsset
    private let address: String
    private let count: Int
    private let page: Int
    private let url: URL

    init(
        chainAsset: ChainAsset,
        filters: [WalletTransactionHistoryFilter],
        url: URL,
        address: String,
        count: Int,
        page: Int
    ) {
        httpProvider = SoramitsuHttpClientProviderImpl()
        soraNetworkClient = SoramitsuNetworkClient(
            timeout: 60000,
            logging: true,
            provider: httpProvider
        )

        subQueryClient = SubQueryClientForSoraWalletFactory()
            .create(
                soramitsuNetworkClient: soraNetworkClient,
                baseUrl: url.absoluteString,
                pageSize: Int32(count)
            )
        self.filters = filters
        self.chainAsset = chainAsset
        self.url = url
        self.address = address
        self.count = count
        self.page = page

        super.init()
    }

    override public func main() {
        super.main()

        if isCancelled {
            return
        }

        if result != nil {
            return
        }

        let semaphore = DispatchSemaphore(value: 0)
        let filter = prepareFilter(for: chainAsset, filters: filters)

        // TODO: delete after kotlin 1.7.0 released, now we should call method from main queue
        DispatchQueue.main.async {
            self.subQueryClient.getTransactionHistoryPaged(
                address: self.address,
                networkName: self.chainAsset.chain.name,
                page: Int64(self.page),
                url: self.url.absoluteString,
                filter: filter,
                completionHandler: { [self] requestResult, _ in
                    guard let data = requestResult as? ResultType else { return }

                    if self.isCancelled {
                        return
                    }
                    semaphore.signal()
                    self.result = .success(data)
                }
            )
        }

        semaphore.wait()
    }

    private func prepareFilter(
        for chainAsset: ChainAsset,
        filters: [WalletTransactionHistoryFilter]
    ) -> ((TxHistoryItem) -> KotlinBoolean)? {
        let currencyId = chainAsset.asset.currencyId
        let filter: ((TxHistoryItem) -> KotlinBoolean)? = { item in
            let callPath = KmmCallCodingPath(moduleName: item.module, callName: item.method)

            if callPath.isTransfer {
                if !filters.contains(where: { $0.type == .transfer && $0.selected }) {
                    return KotlinBoolean(value: false)
                } else {
                    let isAssetId = item.data?.first { $0.paramName == "assetId" }?.paramValue == currencyId
                    return KotlinBoolean(value: isAssetId)
                }
            }

            if callPath.isSwap {
                if !filters.contains(where: { $0.type == .swap && $0.selected }) {
                    return KotlinBoolean(value: false)
                } else {
                    let isBaseAssetId = item.data?.first { $0.paramName == "baseAssetId" }?.paramValue == currencyId
                    let isTargetAssetId = item.data?.first { $0.paramName == "targetAssetId" }?.paramValue == currencyId
                    return KotlinBoolean(value: isBaseAssetId || isTargetAssetId)
                }
            }

            return KotlinBoolean(value: false)
        }

        return currencyId != nil ? filter : nil
    }
}
