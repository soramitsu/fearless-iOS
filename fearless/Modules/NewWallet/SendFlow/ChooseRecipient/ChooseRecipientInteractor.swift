import CommonWallet

final class ChooseRecipientInteractor {
    weak var output: ChooseRecipientInteractorOutputProtocol?

    private let chainAsset: ChainAsset
    private let wallet: MetaAccountModel
    private let searchService: SearchServiceProtocol
    private let scamServiceOperationFactory: ScamServiceOperationFactoryProtocol
    private let operationQueue: OperationQueue

    init(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        searchService: SearchServiceProtocol,
        scamServiceOperationFactory: ScamServiceOperationFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.chainAsset = chainAsset
        self.searchService = searchService
        self.wallet = wallet
        self.scamServiceOperationFactory = scamServiceOperationFactory
        self.operationQueue = operationQueue
    }

    private func fetchScamInfo(for address: String) {
        let allOperation = scamServiceOperationFactory.fetchScamInfoOperation(for: address)

        allOperation.completionBlock = { [weak self] in
            guard let result = allOperation.result else {
                return
            }

            switch result {
            case let .success(scamInfo):
                DispatchQueue.main.async {
                    self?.output?.didReceive(scamInfo: scamInfo)
                }
            case .failure:
                break
            }
        }

        operationQueue.addOperation(allOperation)
    }
}

extension ChooseRecipientInteractor: ChooseRecipientInteractorInputProtocol {
    func setup(with output: ChooseRecipientInteractorOutputProtocol) {
        self.output = output
    }

    func performSearch(query: String) {
        let peerId = try? AddressFactory.accountId(from: query, chain: chainAsset.chain)
        let currentAccountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId

        if let peerId = peerId, let currentAccountId = currentAccountId {
            if currentAccountId != peerId {
                let searchData = SearchData(
                    accountId: peerId.toHex(),
                    firstName: query,
                    lastName: ""
                )

                fetchScamInfo(for: query)

                output?.didReceive(searchResult: .success([searchData]))
                return
            }
        } else {
            output?.didReceive(scamInfo: nil)
        }

        searchService.searchPeople(
            query: query,
            chain: chainAsset.chain,
            filterResults: { searchData in
                searchData.accountId != currentAccountId?.toHex()
            }
        ) { [weak self] result in
            self?.output?.didReceive(searchResult: result)
        }
    }

    func validate(address: String) -> Bool {
        ((try? AddressFactory.accountId(from: address, chain: chainAsset.chain)) != nil)
    }
}
