import UIKit
import CommonWallet
import RobinHood
import IrohaCrypto

final class SearchPeopleInteractor {
    weak var presenter: SearchPeopleInteractorOutputProtocol?

    private let chainAsset: ChainAsset
    private let wallet: MetaAccountModel
    private let searchService: SearchServiceProtocol

    init(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        searchService: SearchServiceProtocol
    ) {
        self.chainAsset = chainAsset
        self.searchService = searchService
        self.wallet = wallet
    }
}

extension SearchPeopleInteractor: SearchPeopleInteractorInputProtocol {
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

                presenter?.didReceive(searchResult: .success([searchData]))
                return
            }
        }

        searchService.searchPeople(
            query: query,
            chain: chainAsset.chain,
            filterResults: { searchData in
                searchData.accountId != currentAccountId?.toHex()
            }
        ) { [weak self] result in
            self?.presenter?.didReceive(searchResult: result)
        }
    }
}
