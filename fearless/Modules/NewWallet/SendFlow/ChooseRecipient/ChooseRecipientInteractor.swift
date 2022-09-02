import CommonWallet

final class ChooseRecipientInteractor {
    weak var presenter: ChooseRecipientInteractorOutputProtocol?

    private let chain: ChainModel
    private let asset: AssetModel
    private let wallet: MetaAccountModel
    private let searchService: SearchServiceProtocol

    init(
        chain: ChainModel,
        asset: AssetModel,
        wallet: MetaAccountModel,
        searchService: SearchServiceProtocol
    ) {
        self.chain = chain
        self.asset = asset
        self.searchService = searchService
        self.wallet = wallet
    }
}

extension ChooseRecipientInteractor: ChooseRecipientInteractorInputProtocol {
    func performSearch(query: String) {
        let peerId = try? AddressFactory.accountId(from: query, chain: chain)
        let currentAccountId = wallet.fetch(for: chain.accountRequest())?.accountId

        if let peerId = peerId, let currentAccountId = currentAccountId {
            if currentAccountId != peerId {
                let searchData = SearchData(
                    accountId: peerId.toHex(),
                    firstName: query,
                    lastName: ""
                )

                presenter?.didReceive(searchResult: .success([searchData]))
                return
            }
        }

        searchService.searchPeople(
            query: query,
            chain: chain,
            filterResults: { searchData in
                searchData.accountId != currentAccountId?.toHex()
            }
        ) { [weak self] result in
            self?.presenter?.didReceive(searchResult: result)
        }
    }

    func validate(address: String) -> Bool {
        guard (try? AddressFactory.accountId(from: address, chain: chain)) != nil else {
            return false
        }
        return true
    }
}
