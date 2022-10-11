import UIKit
import RobinHood
import CommonWallet

final class ContactsInteractor {
    enum Constants {
        static let recentTransfersCount: Int = 100
    }

    // MARK: - Private properties

    private weak var output: ContactsInteractorOutput?
    private let repository: AnyDataProviderRepository<Contact>
    private let operationQueue: OperationQueue
    private let historyOperationFactory: HistoryOperationFactoryProtocol
    private let wallet: MetaAccountModel
    private let chainAsset: ChainAsset
    private(set) var dataLoadingState: WalletTransactionHistoryDataState = .waitingCached

    init(
        repository: AnyDataProviderRepository<Contact>,
        operationQueue: OperationQueue,
        historyOperationFactory: HistoryOperationFactoryProtocol,
        wallet: MetaAccountModel,
        chainAsset: ChainAsset
    ) {
        self.repository = repository
        self.operationQueue = operationQueue
        self.historyOperationFactory = historyOperationFactory
        self.wallet = wallet
        self.chainAsset = chainAsset
    }
}

// MARK: - ContactsInteractorInput

extension ContactsInteractor: ContactsInteractorInput {
    func setup(with output: ContactsInteractorOutput) {
        self.output = output
        fetchContacts()
    }

    func save(contact: Contact) {
        let saveOperation = repository.saveOperation {
            [contact]
        } _: {
            []
        }
        saveOperation.completionBlock = { [weak self] in
            self?.fetchContacts()
        }
        operationQueue.addOperation(saveOperation)
    }
}

private extension ContactsInteractor {
    func fetchContacts() {
        let savedContactsOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())

        guard let address = wallet.fetch(for: chainAsset.chain.accountRequest())?.toAddress() else {
            return
        }

        let pagination = Pagination(count: Constants.recentTransfersCount)
        let filters = [WalletTransactionHistoryFilter(type: .transfer, selected: true),
                       WalletTransactionHistoryFilter(type: .other, selected: false),
                       WalletTransactionHistoryFilter(type: .reward, selected: false)]

        let operationWrapper = historyOperationFactory.fetchSubqueryHistoryOperation(
            asset: chainAsset.asset,
            chain: chainAsset.chain,
            address: address,
            filters: filters,
            pagination: pagination
        )

        let mergeOperation: BaseOperation<(
            savedContacts: [Contact],
            recentContacts: [ContactType]
        )> = ClosureOperation {
            let savedContacts = try? savedContactsOperation.extractNoCancellableResultData().filter { [weak self] in
                $0.chainId == self?.chainAsset.chain.chainId
            }
            let transactionsData = try? operationWrapper.targetOperation.extractNoCancellableResultData()
            let recentAddresses: [String] = Array(Set(transactionsData?.transactions.compactMap { data in
                data.peerName
            } ?? []))
            let recentContacts: [ContactType] = recentAddresses.map { address in
                if let contact = savedContacts?.first(where: { $0.address == address }) {
                    return .saved(contact)
                } else {
                    return .unsaved(address)
                }
            }
            return (
                savedContacts: savedContacts ?? [],
                recentContacts: recentContacts
            )
        }

        mergeOperation.completionBlock = { [weak self] in
            guard let result = mergeOperation.result else {
                return
            }

            switch result {
            case let .success((savedContacts, recentContacts)):
                DispatchQueue.main.async {
                    self?.output?.didReceive(
                        savedContacts: savedContacts,
                        recentContacts: recentContacts
                    )
                }
            case let .failure(error):
                DispatchQueue.main.async {
                    self?.output?.didReceiveError(error)
                }
            }
        }

        mergeOperation.addDependency(savedContactsOperation)
        mergeOperation.addDependency(operationWrapper.targetOperation)

        operationQueue.addOperations(
            operationWrapper.allOperations + [savedContactsOperation, mergeOperation],
            waitUntilFinished: false
        )
    }
}
