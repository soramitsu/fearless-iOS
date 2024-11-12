import Foundation
import SoraFoundation
import SSFModels

final class AllDonePresenter {
    // MARK: Private properties

    private lazy var wallet: MetaAccountModel? = {
        SelectedWalletSettings.shared.value
    }()

    private weak var view: AllDoneViewInput?
    private let router: AllDoneRouterInput
    private let interactor: AllDoneInteractorInput
    private let viewModelFactory: AllDoneViewModelFactoryProtocol

    private let chainAsset: ChainAsset?
    private let hashString: String?
    private var closure: (() -> Void)?

    private var title: String?
    private var description: String?
    private let isWalletConnectResult: Bool

    private var explorer: ChainModel.ExternalApiExplorer?

    // MARK: - Constructors

    init(
        chainAsset: ChainAsset?,
        hashString: String?,
        interactor: AllDoneInteractorInput,
        router: AllDoneRouterInput,
        viewModelFactory: AllDoneViewModelFactoryProtocol,
        closure: (() -> Void)?,
        title: String? = nil,
        description: String? = nil,
        isWalletConnectResult: Bool,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.chainAsset = chainAsset
        self.hashString = hashString
        self.interactor = interactor
        self.router = router
        self.viewModelFactory = viewModelFactory
        self.closure = closure
        self.title = title
        self.description = description
        self.isWalletConnectResult = isWalletConnectResult
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func provideViewModel() {
        let viewModel = viewModelFactory.buildViewModel(
            title: title,
            description: description,
            extrinsicHash: hashString,
            locale: selectedLocale,
            isWalletConnectResult: isWalletConnectResult
        )

        view?.didReceive(viewModel: viewModel)
    }

    private func prepareExplorer() {
        if chainAsset?.chain.ecosystem == .ton {
            let explorer = chainAsset?.chain.externalApi?.explorers?.first(where: { $0.types.contains(.tonAccount) })
            view?.didReceive(explorer: explorer)
            self.explorer = explorer
            return
        }
        guard hashString != nil else {
            view?.didReceive(explorer: nil)
            return
        }
        let explorer = chainAsset?.chain.externalApi?.explorers?.first
        view?.didReceive(explorer: explorer)
        self.explorer = explorer
    }
}

// MARK: - AllDoneViewOutput

extension AllDonePresenter: AllDoneViewOutput {
    func didLoad(view: AllDoneViewInput) {
        self.view = view
        interactor.setup(with: self)
        provideViewModel()
        prepareExplorer()
    }

    func explorerButtonDidTapped() {
        guard let url = prepareUrl() else {
            return
        }
        router.presentSubscan(from: view, url: url)
    }

    func shareButtonDidTapped() {
        guard let url = prepareUrl() else {
            return
        }
        router.share(sources: [url], from: view, with: nil)
    }

    private func prepareUrl() -> URL? {
        guard let chainAsset else {
            return nil
        }
        let url: URL
        switch chainAsset.chain.ecosystem {
        case .ethereumBased, .ethereum, .substrate:
            guard
                let explorer = self.explorer,
                let hashString = hashString,
                let explorerUrl = explorer.explorerUrl(for: hashString, type: explorer.transactionType)
            else {
                return nil
            }
            url = explorerUrl
        case .ton:
            guard
                let wallet,
                let explorer,
                let address = try? wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId.asTonAddress().toRaw(),
                let explorerUrl = explorer.explorerUrl(for: address, type: .tonAccount)
            else {
                return nil
            }
            url = explorerUrl
        }
        return url
    }

    func dismiss() {
        router.dismiss(view: view)
    }

    func didCopyTapped() {
        let copyEvent = HashCopiedEvent(locale: selectedLocale)
        router.presentStatus(with: copyEvent, animated: true)
    }

    func presentationControllerWillDismiss() {
        closure?()
    }
}

// MARK: - AllDoneInteractorOutput

extension AllDonePresenter: AllDoneInteractorOutput {}

// MARK: - Localizable

extension AllDonePresenter: Localizable {
    func applyLocalization() {
        provideViewModel()
    }
}

extension AllDonePresenter: AllDoneModuleInput {}
