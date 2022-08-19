import Foundation
import SoraFoundation

final class StakingPoolMainPresenter {
    // MARK: Private properties

    private weak var view: StakingPoolMainViewInput?
    private let router: StakingPoolMainRouterInput
    private let interactor: StakingPoolMainInteractorInput
    private let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    private weak var moduleOutput: StakingMainModuleOutput?

    private var accountInfo: AccountInfo?
    private var chainAsset: ChainAsset?
    private var balance: Decimal?

    // MARK: - Constructors

    init(
        interactor: StakingPoolMainInteractorInput,
        router: StakingPoolMainRouterInput,
        localizationManager: LocalizationManagerProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        moduleOutput: StakingMainModuleOutput?
    ) {
        self.interactor = interactor
        self.router = router
        self.balanceViewModelFactory = balanceViewModelFactory
        self.localizationManager = localizationManager
        self.moduleOutput = moduleOutput
    }

    // MARK: - Private methods

    private func provideBalanceViewModel() {
        if let availableValue = accountInfo?.data.available, let chainAsset = chainAsset {
            balance = Decimal.fromSubstrateAmount(
                availableValue,
                precision: Int16(chainAsset.asset.precision)
            )
        } else {
            balance = 0.0
        }

        let balanceViewModel = balanceViewModelFactory.balanceFromPrice(balance ?? 0.0, priceData: nil)
        view?.didReceiveBalanceViewModel(balanceViewModel.value(for: selectedLocale))
    }
}

// MARK: - StakingPoolMainViewOutput

extension StakingPoolMainPresenter: StakingPoolMainViewOutput {
    func didLoad(view: StakingPoolMainViewInput) {
        self.view = view
        interactor.setup(with: self)
    }

    func performAssetSelection() {
        router.showChainAssetSelection(
            from: view,
            type: .pool(chainAsset: chainAsset),
            delegate: self
        )
    }
}

// MARK: - StakingPoolMainInteractorOutput

extension StakingPoolMainPresenter: StakingPoolMainInteractorOutput {
    func didReceive(accountInfo _: AccountInfo?) {
        provideBalanceViewModel()
    }

    func didReceive(balanceError _: Error) {}

    func didReceive(chainAsset: ChainAsset) {
        self.chainAsset = chainAsset

        provideBalanceViewModel()

        view?.didReceiveChainAsset(chainAsset)
    }
}

// MARK: - Localizable

extension StakingPoolMainPresenter: Localizable {
    func applyLocalization() {}
}

extension StakingPoolMainPresenter: StakingPoolMainModuleInput {}

extension StakingPoolMainPresenter: AssetSelectionDelegate {
    func assetSelection(
        view _: ChainSelectionViewProtocol,
        didCompleteWith chainAsset: ChainAsset,
        context: Any?
    ) {
        guard let type = context as? AssetSelectionStakingType, let chainAsset = type.chainAsset else {
            return
        }

        interactor.save(chainAsset: chainAsset)

        switch type {
        case .normal:
            moduleOutput?.didSwitchStakingType(type)
        case .pool:
            break
        }
    }
}
