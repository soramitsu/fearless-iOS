import Foundation
import SoraFoundation
import CommonWallet
import BigInt

final class StakingPoolJoinConfigPresenter {
    // MARK: Private properties

    private weak var view: StakingPoolJoinConfigViewInput?
    private let router: StakingPoolJoinConfigRouterInput
    private let interactor: StakingPoolJoinConfigInteractorInput
    private let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    private let accountViewModelFactory: AccountViewModelFactoryProtocol
    private let wallet: MetaAccountModel
    private let chainAsset: ChainAsset
    private let logger: LoggerProtocol?

    private var inputResult: AmountInputResult?
    private var balance: Decimal?
    private var priceData: PriceData?
    private var amountViewModel: AmountInputViewModelProtocol?
    private var fee: Decimal?
    private var balanceMinusFee: Decimal { (balance ?? 0) - (fee ?? 0) }

    // MARK: - Constructors

    init(
        interactor: StakingPoolJoinConfigInteractorInput,
        router: StakingPoolJoinConfigRouterInput,
        localizationManager: LocalizationManagerProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        accountViewModelFactory: AccountViewModelFactoryProtocol,
        wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        logger: LoggerProtocol?
    ) {
        self.interactor = interactor
        self.router = router
        self.balanceViewModelFactory = balanceViewModelFactory
        self.accountViewModelFactory = accountViewModelFactory
        self.wallet = wallet
        self.chainAsset = chainAsset
        self.logger = logger
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func provideAccountViewModel() {
        let title = R.string.localizable.poolStakingJoinTitle(
            preferredLanguages: selectedLocale.rLanguages
        )

        let accountViewModel = accountViewModelFactory.buildViewModel(
            title: title,
            address: wallet.name,
            locale: selectedLocale
        )

        view?.didReceiveAccountViewModel(accountViewModel)
    }

    private func provideAssetVewModel() {
        let inputAmount = inputResult?.absoluteValue(from: balanceMinusFee) ?? 0.0

        let assetBalanceViewModel = balanceViewModelFactory.createAssetBalanceViewModel(
            inputAmount,
            balance: balance,
            priceData: priceData
        ).value(for: selectedLocale)

        view?.didReceiveAssetBalanceViewModel(assetBalanceViewModel)
    }

    private func provideInputViewModel() {
        let inputAmount = inputResult?.absoluteValue(from: balanceMinusFee)

        let inputViewModel = balanceViewModelFactory.createBalanceInputViewModel(inputAmount)
            .value(for: selectedLocale)
        view?.didReceiveAmountInputViewModel(inputViewModel)
    }
}

// MARK: - StakingPoolJoinConfigViewOutput

extension StakingPoolJoinConfigPresenter: StakingPoolJoinConfigViewOutput {
    func selectAmountPercentage(_ percentage: Float) {
        inputResult = .rate(Decimal(Double(percentage)))
        provideInputViewModel()
    }

    func updateAmount(_ newValue: Decimal) {
        inputResult = .absolute(newValue)
        provideInputViewModel()
    }

    func didTapBackButton() {
        router.dismiss(view: view)
    }

    func didTapContinueButton() {}

    func didLoad(view: StakingPoolJoinConfigViewInput) {
        self.view = view
        interactor.setup(with: self)

        view.didReceive(locale: selectedLocale)

        provideAccountViewModel()
        provideAssetVewModel()
        provideInputViewModel()

        interactor.estimateFee()
    }
}

// MARK: - StakingPoolJoinConfigInteractorOutput

extension StakingPoolJoinConfigPresenter: StakingPoolJoinConfigInteractorOutput {
    func didReceivePriceData(result: Result<PriceData?, Error>) {
        switch result {
        case let .success(priceData):
            self.priceData = priceData

            provideAssetVewModel()
            provideInputViewModel()
        case let .failure(error):
            logger?.error("StakingPoolJoinConfigPresenter.didReceivePriceData.error: \(error)")
        }
    }

    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>) {
        switch result {
        case let .success(accountInfo):
            if let accountInfo = accountInfo {
                balance = Decimal.fromSubstrateAmount(
                    accountInfo.data.available,
                    precision: Int16(chainAsset.asset.precision)
                )
            } else {
                balance = nil
            }

            provideAssetVewModel()
        case let .failure(error):
            logger?.error("StakingPoolJoinConfigPresenter.didReceiveAccountInfo.error: \(error)")
        }
    }

    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>) {
        switch result {
        case let .success(dispatchInfo):
            if let feeValue = BigUInt(dispatchInfo.fee) {
                fee = Decimal.fromSubstrateAmount(feeValue, precision: Int16(chainAsset.asset.precision))
            } else {
                fee = nil
            }

            provideAssetVewModel()
        case let .failure(error):
            logger?.error("StakingPoolJoinConfigPresenter.didReceiveFee.error: \(error)")
        }
    }
}

// MARK: - Localizable

extension StakingPoolJoinConfigPresenter: Localizable {
    func applyLocalization() {}
}

extension StakingPoolJoinConfigPresenter: StakingPoolJoinConfigModuleInput {}
