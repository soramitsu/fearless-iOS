import Foundation
import SoraFoundation
import SSFModels

final class AddERC20TokenPresenter {
    // MARK: - Private properties

    weak var view: AddERC20TokenViewInput?
    private let interactor: AddERC20TokenInteractorInput
    private let router: AddERC20TokenRouterInput
    private let logger: LoggerProtocol
    private let localizationManager: LocalizationManagerProtocol
    private let wallet: MetaAccountModel
    private weak var moduleOutput: AddERC20TokenModuleOutput?

    private var currentTokenInfo: ERC20TokenInfo?
    private var isLoading = false {
        didSet {
            view?.didReceive(isLoading: isLoading)
        }
    }
    private var selectedChain: ChainModel?
    private var debounceTimer: Timer?

    // MARK: - Constructors

    init(
        wallet: MetaAccountModel,
        interactor: AddERC20TokenInteractorInput,
        router: AddERC20TokenRouterInput,
        logger: LoggerProtocol,
        localizationManager: LocalizationManagerProtocol,
        moduleOutput: AddERC20TokenModuleOutput?
    ) {
        self.wallet = wallet
        self.interactor = interactor
        self.router = router
        self.logger = logger
        self.localizationManager = localizationManager
        self.moduleOutput = moduleOutput
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
        guard let tokenInfo = currentTokenInfo, let chain = selectedChain else { return }
        
        isLoading = true
        provideViewModel()
        
        interactor.saveToken(tokenInfo, for: chain)
    }

    func didChangeTokenAddress(_ address: String) {
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            self?.validateTokenAddress(address)
        }
    }
    
    private func validateTokenAddress(_ address: String) {
        let ethereumAddressRegex = "^0x[a-fA-F0-9]{40}$"
        let addressPredicate = NSPredicate(format: "SELF MATCHES %@", ethereumAddressRegex)
        
        guard addressPredicate.evaluate(with: address), let selectedChain = selectedChain else {
            currentTokenInfo = nil
            provideViewModel()
            return
        }
        
        isLoading = true
        
        Task {
            do {
                try await interactor.validateAndFetchToken(
                    address: address,
                    chain: selectedChain
                )
            } catch {
                if let view {
                    await MainActor.run {
                        isLoading = false
                        router.presentError(
                            for: error.localizedDescription,
                            message: "",
                            view: view,
                            locale: selectedLocale
                        )
                    }
                }
            }
        }
    }
    
    func didTapSelectNetwork() {
        router.showSelectNetwork(
            from: view,
            wallet: wallet,
            selectedChainId: selectedChain?.chainId,
            chainModels: nil,
            contextTag: nil,
            delegate: self
        )
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

        if let view {
            router.presentError(
                for: error.localizedDescription,
                message: "",
                view: view,
                locale: selectedLocale
            )
        }

    }

    func didFinishSavingToken(chainAsset: ChainAsset) {
        isLoading = false
        moduleOutput?.didFinishAddingToken(chainAsset: chainAsset)
        router.dismiss(view: view)
    }
}

// MARK: - Localizable

extension AddERC20TokenPresenter: Localizable {
    func applyLocalization() {
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

    func provideSelectNetworkViewModel() {
        guard let chain = selectedChain else {
            view?.didReceive(selectNetworkViewModel: nil)
            return
        }

        let viewModel = SelectNetworkViewModel(
            chainName: chain.name,
            iconViewModel: chain.icon.map { RemoteImageViewModel(url: $0) }
        )
        
        view?.didReceive(selectNetworkViewModel: viewModel)
    }
}

extension AddERC20TokenPresenter: SelectNetworkDelegate {
    func chainSelection(
        view _: SelectNetworkViewInput,
        didCompleteWith chain: ChainModel?,
        contextTag _: Int?
    ) {
        guard let chain = chain else {
            return
        }

        if selectedChain?.chainId != chain.chainId {
            currentTokenInfo = nil
            provideViewModel()
        }
        
        selectedChain = chain
        provideSelectNetworkViewModel()
    }
}

extension AddERC20TokenPresenter: AddERC20TokenModuleInput {}
