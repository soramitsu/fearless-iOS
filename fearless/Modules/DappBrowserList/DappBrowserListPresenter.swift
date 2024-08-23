import Foundation
import SSFModels
import SoraFoundation

protocol DappBrowserListViewInput: ControllerBackedProtocol {
    func didReceive(viewModels: [DappBrowserListCellViewModel])
}

protocol DappBrowserListInteractorInput: AnyObject {
    func setup(with output: DappBrowserListInteractorOutput)
}

final class DappBrowserListPresenter {
    // MARK: Private properties
    private weak var view: DappBrowserListViewInput?
    private let router: DappBrowserListRouterInput
    private let interactor: DappBrowserListInteractorInput
    
    private let wallet: MetaAccountModel
    private let dapps: [TonDapp]

    // MARK: - Constructors
    init(
        wallet: MetaAccountModel,
        dapps: [TonDapp],
        interactor: DappBrowserListInteractorInput,
        router: DappBrowserListRouterInput,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.wallet = wallet
        self.dapps = dapps
        self.interactor = interactor
        self.router = router
        self.localizationManager = localizationManager
    }
    
    // MARK: - Private methods
    
    private func provideViewModel(search: String?) {
        var apps = dapps
        if let search, search.isNotEmpty {
            apps = dapps.filter { $0.name.lowercased().contains(search.lowercased()) }
        }
        let viewModels = apps
            .map {
            DappBrowserListCellViewModel(
                icon: RemoteImageViewModel(url: $0.url), 
                iconUrl: $0.icon,
                name: $0.name,
                description: $0.description,
                dapp: $0
            )
        }
        view?.didReceive(viewModels: viewModels)
    }
}

// MARK: - DappBrowserListViewOutput
extension DappBrowserListPresenter: DappBrowserListViewOutput {
    func didSelect(dapp: TonDapp) {
        router.showDapp(
            from: view,
            dapp: dapp,
            wallet: wallet
        )
    }
    
    func searchTextDidChanged(_ text: String?) {
        provideViewModel(search: text)
    }
    
    func didTapBackButton() {
        router.dismiss(view: view)
    }
    
    func didLoad(view: DappBrowserListViewInput) {
        self.view = view
        interactor.setup(with: self)
        provideViewModel(search: nil)
    }
}

// MARK: - DappBrowserListInteractorOutput
extension DappBrowserListPresenter: DappBrowserListInteractorOutput {}

// MARK: - Localizable
extension DappBrowserListPresenter: Localizable {
    func applyLocalization() {}
}

extension DappBrowserListPresenter: DappBrowserListModuleInput {}
