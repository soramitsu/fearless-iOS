import Foundation
import SoraFoundation

final class AddERC20TokenPresenter {
    // MARK: - Private properties

    weak var view: AddERC20TokenViewInput?
    private let interactor: AddERC20TokenInteractorInput
    private let router: AddERC20TokenRouterInput
    private let logger: LoggerProtocol
    private let localizationManager: LocalizationManagerProtocol

    private var currentTokenInfo: ERC20TokenInfo?
    private var isLoading = false

    // MARK: - Constructors

    init(
        interactor: AddERC20TokenInteractorInput,
        router: AddERC20TokenRouterInput,
        logger: LoggerProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.router = router
        self.logger = logger
        self.localizationManager = localizationManager
    }
}

// MARK: - AddERC20TokenViewOutput

extension AddERC20TokenPresenter: AddERC20TokenViewOutput {
    func didLoad(view: AddERC20TokenViewInput) {
        self.view = view
        interactor.setup(with: self)
        provideViewModel()
    }

    func didTapSave() {
        guard let tokenInfo = currentTokenInfo else { return }
        
        isLoading = true
        provideViewModel()
        
        interactor.saveToken(tokenInfo)
    }

    func didChangeTokenAddress(_ address: String) {
        guard !address.isEmpty else {
            currentTokenInfo = nil
            provideViewModel()
            return
        }

        isLoading = true
        provideViewModel()
        
        interactor.validateAndFetchToken(address: address)
    }
}

// MARK: - AddERC20TokenInteractorOutput

extension AddERC20TokenPresenter: AddERC20TokenInteractorOutput {
    func didReceive(tokenInfo: ERC20TokenInfo) {
        currentTokenInfo = tokenInfo
        isLoading = false
        provideViewModel()
    }

    func didReceive(error: Error) {
        logger.customError(error)
        isLoading = false
        //TODO: Handle custom error
        router.present(error: error, from: view, locale: selectedLocale)
    }
}

// MARK: - ADDERC20TokenModuleInput

extension AddERC20TokenPresenter: AddERC20TokenModuleInput { }

// MARK: - Localizable

extension AddERC20TokenPresenter: Localizable {
    func applyLocalization() {
        // Здесь можно добавить локализацию, если потребуется
    }
}

// MARK: - Private methods

private extension AddERC20TokenPresenter {
    func provideViewModel() {
        let viewModel = AddERC20TokenViewModel(
            tokenAddress: currentTokenInfo?.address ?? "",
            tokenName: currentTokenInfo?.name,
            tokenSymbol: currentTokenInfo?.symbol,
            tokenDecimals: currentTokenInfo?.decimals,
            tokenTotalSupply: currentTokenInfo?.totalSupply,
            isSaveEnabled: currentTokenInfo != nil && !isLoading,
            isLoading: isLoading
        )

        view?.didReceive(viewModel: viewModel)
    }
}
