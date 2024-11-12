import Foundation
import SSFModels
import SoraFoundation

protocol EcosystemOptionsViewInput: ControllerBackedProtocol {}

protocol EcosystemOptionsInteractorInput: AnyObject {
    func setup(with output: EcosystemOptionsInteractorOutput)
    func getAvailableExportOptions(for ecosystem: Ecosystem) -> [ExportOption]
}

final class EcosystemOptionsPresenter {
    // MARK: Private properties
    private weak var moduleOutput: EcosystemOptionsModuleOutput?
    private weak var view: EcosystemOptionsViewInput?
    private let router: EcosystemOptionsRouterInput
    private let interactor: EcosystemOptionsInteractorInput

    private let wallet: MetaAccountModel
    private let chains: [ChainModel]
    private let ecosystem: Ecosystem

    // MARK: - Constructors
    init(
        ecosystem: Ecosystem,
        wallet: MetaAccountModel,
        chains: [ChainModel],
        moduleOutput: EcosystemOptionsModuleOutput?,
        interactor: EcosystemOptionsInteractorInput,
        router: EcosystemOptionsRouterInput,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.ecosystem = ecosystem
        self.wallet = wallet
        self.chains = chains
        self.moduleOutput = moduleOutput
        self.interactor = interactor
        self.router = router
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func prepareChainAccountInfos() -> [ChainAccountInfo] {
        let chainAccountsInfo = chains.compactMap { chain -> ChainAccountInfo? in
            guard let accountResponse = wallet.fetch(for: chain.accountRequest()), !accountResponse.isChainAccount else {
                return nil
            }
            return ChainAccountInfo(
                chain: chain,
                account: accountResponse
            )
        }.compactMap { $0 }
        return chainAccountsInfo
    }
}

// MARK: - EcosystemOptionsViewOutput
extension EcosystemOptionsPresenter: EcosystemOptionsViewOutput {
    func didTapOnBackup() {
        let options = interactor.getAvailableExportOptions(for: ecosystem)
        let accounts = prepareChainAccountInfos()
        let flow: ExportFlow = .multiple(wallet: wallet, accounts: accounts)

        router.dismiss(view: view)
        if options.contains(.mnemonic) {
            moduleOutput?.showMnemonicExport(flow: flow)
        } else if options.contains(.seed) {
            moduleOutput?.showSeedExport(flow: flow)
        } else {
            moduleOutput?.showKeystoreExport(flow: flow)
        }
    }

    func didTapOnAccounts() {
        router.dismiss(view: view)
        moduleOutput?.showWalletDetails(chains: chains)
    }

    func didLoad(view: EcosystemOptionsViewInput) {
        self.view = view
        interactor.setup(with: self)
    }
}

// MARK: - EcosystemOptionsInteractorOutput
extension EcosystemOptionsPresenter: EcosystemOptionsInteractorOutput {}

// MARK: - Localizable
extension EcosystemOptionsPresenter: Localizable {
    func applyLocalization() {}
}

extension EcosystemOptionsPresenter: EcosystemOptionsModuleInput {}
