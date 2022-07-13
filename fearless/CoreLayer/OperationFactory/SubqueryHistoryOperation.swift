import RobinHood
import XNetworking
import CommonWallet

public final class SubqueryHistoryOperation: BaseOperation<SubqueryHistoryData> {
    private let httpProvider: SoramitsuHttpClientProviderImpl
    private let soraNetworkClient: SoramitsuNetworkClient
    private let subQueryClient: SubQueryClient<FearlessSubQueryResponse, SubQueryHistoryItem>
    private let address: String
    private let count: Int
    private let page: Int
    private let filters: [WalletTransactionHistoryFilter]
    private let baseUrl: URL
    private let chain: ChainModel

    init(
        baseUrl: URL,
        filters: [WalletTransactionHistoryFilter],
        address: String,
        count: Int,
        page: Int,
        chain: ChainModel
    ) {
        httpProvider = SoramitsuHttpClientProviderImpl()
        soraNetworkClient = SoramitsuNetworkClient(timeout: 60000, logging: true, provider: httpProvider)

        subQueryClient = SubQueryClientForFearless().build(
            soramitsuNetworkClient: soraNetworkClient,
            baseUrl: baseUrl.absoluteString,
            pageSize: Int32(count)
        )
        self.address = address
        self.count = count
        self.page = page
        self.filters = filters
        self.baseUrl = baseUrl
        self.chain = chain

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

        let filter: ((SubQueryHistoryItem?) -> KotlinBoolean)? = { [weak self] item in
            guard let self = self, let item = item else { return false }

            var conditions: [Bool] = []

            if !self.filters.contains(where: { $0.type == .other && $0.selected }) {
                conditions.append(item.module == "reward" || item.module == "transfer")
            }

            if !self.filters.contains(where: { $0.type == .reward && $0.selected }) {
                conditions.append(item.module == "extrinsic" || item.module == "transfer")
            }

            if !self.filters.contains(where: { $0.type == .transfer && $0.selected }) {
                conditions.append(item.module == "extrinsic" || item.module == "reward")
            }

            return KotlinBoolean(bool: (conditions.allSatisfy { $0 }) || conditions.isEmpty)
        }

        // TODO: delete after updating X-Networking to kotlin 1.7.0, now we should call method from main queue
        DispatchQueue.main.async {
            self.subQueryClient.getTransactionHistoryPaged(
                address: self.address,
                networkName: self.chain.name,
                page: Int64(self.page),
                url: self.baseUrl.absoluteString,
                filter: filter,
                completionHandler: { [weak self] requestResult, _ in
                    guard let self = self, let data = requestResult else { return }

                    if self.isCancelled {
                        return
                    }

                    let items: [SubQueryHistoryItem] = (data.items as? [SubQueryHistoryItem]) ?? []
                    let nodes: [SubqueryHistoryElement] = items.map { item in

                        if item.module == "reward" {
                            return self.createRewardSubqueryHistoryElement(with: item)
                        }

                        if item.module == "extrinsic" {
                            return self.createExtrinsicSubqueryHistoryElement(with: item)
                        }

                        if item.module == "transfer" {
                            return self.createTransferSubqueryHistoryElement(with: item)
                        }

                        return self.createUnidentifiedSubqueryHistoryElement(with: item)
                    }

                    let endCursor = "\((requestResult?.page ?? 1) + 1)"
                    let pageInfo = SubqueryPageInfo(startCursor: String(self.page), endCursor: endCursor)
                    let historyElements = SubqueryHistoryData.HistoryElements(pageInfo: pageInfo, nodes: nodes)
                    let result = SubqueryHistoryData(historyElements: historyElements)

                    self.result = .success(result)

                    semaphore.signal()
                }
            )
        }

        semaphore.wait()
    }
}

private extension SubqueryHistoryOperation {
    func createRewardSubqueryHistoryElement(with item: SubQueryHistoryItem) -> SubqueryHistoryElement {
        let amount = item.data?.first { $0.paramName == "amount" }?.paramValue ?? ""
        let isReward = item.data?.first { $0.paramName == "isReward" }?.paramValue == "true"
        let era = Int(item.data?.first { $0.paramName == "era" }?.paramValue ?? "")
        let validator = item.data?.first { $0.paramName == "validator" }?.paramValue

        let reward = SubqueryRewardOrSlash(
            amount: amount,
            isReward: isReward,
            era: era,
            validator: validator,
            stash: nil,
            eventIdx: nil
        )

        return SubqueryHistoryElement(
            identifier: item.id,
            timestamp: item.timestamp,
            address: address,
            reward: reward,
            extrinsic: nil,
            transfer: nil
        )
    }

    func createExtrinsicSubqueryHistoryElement(with item: SubQueryHistoryItem) -> SubqueryHistoryElement {
        let hash = item.data?.first { $0.paramName == "hash" }?.paramValue ?? ""
        let module = item.data?.first { $0.paramName == "module" }?.paramValue ?? ""
        let call = item.data?.first { $0.paramName == "call" }?.paramValue ?? ""
        let fee = item.data?.first { $0.paramName == "fee" }?.paramValue ?? ""
        let success = item.data?.first { $0.paramName == "success" }?.paramValue == "true"

        let extrinsic = SubqueryExtrinsic(
            hash: hash,
            module: module,
            call: call,
            fee: fee,
            success: success
        )

        return SubqueryHistoryElement(
            identifier: item.id,
            timestamp: item.timestamp,
            address: address,
            reward: nil,
            extrinsic: extrinsic,
            transfer: nil
        )
    }

    func createTransferSubqueryHistoryElement(with item: SubQueryHistoryItem) -> SubqueryHistoryElement {
        let amount = item.data?.first { $0.paramName == "amount" }?.paramValue ?? ""
        let receiver = item.data?.first { $0.paramName == "to" }?.paramValue ?? ""
        let sender = item.data?.first { $0.paramName == "from" }?.paramValue ?? ""
        let block = item.data?.first { $0.paramName == "block" }?.paramValue ?? ""
        let extrinsicHash = item.data?.first { $0.paramName == "extrinsicHash" }?.paramValue ?? ""
        let fee = item.data?.first { $0.paramName == "fee" }?.paramValue ?? ""
        let success = item.data?.first { $0.paramName == "success" }?.paramValue == "true"

        let transfer = SubqueryTransfer(
            amount: amount,
            receiver: receiver,
            sender: sender,
            fee: fee,
            block: block,
            extrinsicId: nil,
            extrinsicHash: extrinsicHash,
            success: success
        )

        return SubqueryHistoryElement(
            identifier: item.id,
            timestamp: item.timestamp,
            address: address,
            reward: nil,
            extrinsic: nil,
            transfer: transfer
        )
    }

    func createUnidentifiedSubqueryHistoryElement(with item: SubQueryHistoryItem) -> SubqueryHistoryElement {
        SubqueryHistoryElement(
            identifier: item.id,
            timestamp: item.timestamp,
            address: address,
            reward: nil,
            extrinsic: nil,
            transfer: nil
        )
    }
}
