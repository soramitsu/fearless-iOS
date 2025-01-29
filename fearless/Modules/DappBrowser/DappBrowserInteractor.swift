import UIKit
import SoraKeystore
import RobinHood
import SSFModels

protocol DappBrowserInteractorOutput: AnyObject {
    func didReceive(dapps: Result<[DappCategory], Error>)
    func didUpdate(wallet: MetaAccountModel)
}

final class DappBrowserInteractor {
    // MARK: - Private properties

    private enum Constants {
        static let filterKey = "jp.co.soramitsu.fearless.dapp.browser.filter"
    }

    private weak var output: DappBrowserInteractorOutput?
    private let dappProvider: AnySingleValueProvider<[DappCategory]>
    private let appRepository: AsyncAnyRepository<TonConnectApp>
    private let chainsRepository: AsyncAnyRepository<ChainModel>
    private let filterStorage: SettingsManagerProtocol
    private let eventCenter: EventCenterProtocol

    init(
        dappProvider: AnySingleValueProvider<[DappCategory]>,
        appRepository: AsyncAnyRepository<TonConnectApp>,
        chainsRepository: AsyncAnyRepository<ChainModel>,
        filterStorage: SettingsManagerProtocol,
        eventCenter: EventCenterProtocol
    ) {
        self.dappProvider = dappProvider
        self.appRepository = appRepository
        self.chainsRepository = chainsRepository
        self.filterStorage = filterStorage
        self.eventCenter = eventCenter
        eventCenter.add(observer: self)
    }

    private func setupDappProvider() {
        let updateClosure = { [weak self] (changes: [DataProviderChange<[DappCategory]>]) in
            guard let dapps = changes.reduceToLastChange() else {
                return
            }
            self?.output?.didReceive(dapps: .success(dapps))
        }

        let failureClosure: (any Error) -> Void = { [weak self] (error: Error) in
            self?.output?.didReceive(dapps: .failure(error))
        }

        dappProvider.addObserver(
            self,
            deliverOn: nil,
            executing: updateClosure,
            failing: failureClosure,
            options: DataProviderObserverOptions()
        )
    }
}

// MARK: - DappBrowserInteractorInput

extension DappBrowserInteractor: DappBrowserInteractorInput {
    var connectedApps: [TonConnectApp] {
        get async throws {
            try await appRepository.fetchAll()
        }
    }

    var chains: [ChainModel] {
        get async throws {
            try await chainsRepository.fetchAll()
        }
    }

    var filter: NetworkManagmentFilter {
        get {
            let id = filterStorage.string(for: Constants.filterKey)
            return NetworkManagmentFilter(identifier: id)
        }
        set {
            filterStorage.set(value: newValue.identifier, for: Constants.filterKey)
        }
    }

    func setup(with output: DappBrowserInteractorOutput) {
        self.output = output
        setupDappProvider()
    }
}

extension DappBrowserInteractor: EventVisitorProtocol {
    func processMetaAccountChanged(event: MetaAccountModelChangedEvent) {
        output?.didUpdate(wallet: event.account)
    }
    
    func processSelectedCurrencyChanged(event: SelectedCurrencyChangedEvent) {
        output?.didUpdate(wallet: event.account)
    }

    func processSelectedAccountChanged(event: SelectedAccountChanged) {
        output?.didUpdate(wallet: event.account)
    }
}
