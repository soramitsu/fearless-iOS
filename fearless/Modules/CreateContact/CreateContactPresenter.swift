import Foundation
import SoraFoundation

final class CreateContactPresenter {
    // MARK: Private properties

    private weak var view: CreateContactViewInput?
    private let router: CreateContactRouterInput
    private let interactor: CreateContactInteractorInput
    private let viewModelFactory: CreateContactViewModelFactoryProtocol
    private let moduleOutput: CreateContactModuleOutput
    private let wallet: MetaAccountModel
    private var chain: ChainModel
    private var address: String?
    private var name: String?

    // MARK: - Constructors

    init(
        interactor: CreateContactInteractorInput,
        router: CreateContactRouterInput,
        localizationManager: LocalizationManagerProtocol,
        viewModelFactory: CreateContactViewModelFactoryProtocol,
        moduleOutput: CreateContactModuleOutput,
        wallet: MetaAccountModel,
        chain: ChainModel,
        address: String?
    ) {
        self.interactor = interactor
        self.router = router
        self.viewModelFactory = viewModelFactory
        self.moduleOutput = moduleOutput
        self.wallet = wallet
        self.chain = chain
        self.address = address

        self.localizationManager = localizationManager
    }

    // MARK: - Private methods
}

// MARK: - CreateContactViewOutput

extension CreateContactPresenter: CreateContactViewOutput {
    func didTapBackButton() {
        router.dismiss(view: view)
    }

    func didTapCreateButton() {
        if let name = self.name, let address = self.address {
            let contact = Contact(name: name, address: address, chainId: chain.chainId)
            moduleOutput.didCreate(contact: contact)
            router.dismiss(view: view)
        }
    }

    func didTapSelectNetwork() {
        router.showSelectNetwork(
            from: view,
            wallet: wallet,
            selectedChainId: chain.chainId,
            delegate: self
        )
    }

    func didLoad(view: CreateContactViewInput) {
        self.view = view
        interactor.setup(with: self)
        provideViewModel()
    }

    func addressTextDidChanged(_ address: String) {
        self.address = address
        view?.updateState(isValid: validate())
    }

    func nameTextDidChanged(_ name: String) {
        self.name = name
        view?.updateState(isValid: validate())
    }
}

// MARK: - CreateContactInteractorOutput

extension CreateContactPresenter: CreateContactInteractorOutput {}

private extension CreateContactPresenter {
    func provideViewModel() {
        let viewModel = viewModelFactory.buildViewModel(address: address, chain: chain)
        view?.didReceive(viewModel: viewModel)
    }

    func validate() -> Bool {
        guard let name = name, name.isNotEmpty, let address = self.address else {
            return false
        }
        return interactor.validate(address: address, for: chain)
    }
}

// MARK: - Localizable

extension CreateContactPresenter: Localizable {
    func applyLocalization() {
        view?.didReceive(locale: selectedLocale)
    }
}

extension CreateContactPresenter: CreateContactModuleInput {}

extension CreateContactPresenter: SelectNetworkDelegate {
    func chainSelection(
        view _: SelectNetworkViewInput,
        didCompleteWith chain: ChainModel?
    ) {
        if let selectedChain = chain {
            self.chain = selectedChain
            provideViewModel()
            view?.updateState(isValid: validate())
        }
    }
}
