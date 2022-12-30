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
    private let dataValidatingFactory: StakingDataValidatingFactoryProtocol

    private var inputResult: AmountInputResult?
    private var balance: Decimal?
    private var priceData: PriceData?
    private var amountViewModel: AmountInputViewModelProtocol?
    private var fee: Decimal?
    private var balanceMinusFee: Decimal { (balance ?? 0) - (fee ?? 0) }
    private var minJoinBond: Decimal?
    private var existentialDeposit: BigUInt?
    private var totalAmount: BigUInt?

    // MARK: - Constructors

    init(
        interactor: StakingPoolJoinConfigInteractorInput,
        router: StakingPoolJoinConfigRouterInput,
        localizationManager: LocalizationManagerProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        accountViewModelFactory: AccountViewModelFactoryProtocol,
        wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        logger: LoggerProtocol?,
        dataValidatingFactory: StakingDataValidatingFactoryProtocol,
        amount: Decimal?
    ) {
        self.interactor = interactor
        self.router = router
        self.balanceViewModelFactory = balanceViewModelFactory
        self.accountViewModelFactory = accountViewModelFactory
        self.wallet = wallet
        self.chainAsset = chainAsset
        self.logger = logger
        self.dataValidatingFactory = dataValidatingFactory

        if let amount = amount {
            inputResult = .absolute(amount)
        }

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

    private func provideFeeViewModel() {
        guard let fee = fee else {
            view?.didReceiveFeeViewModel(nil)
            return
        }

        let feeViewModel = balanceViewModelFactory.balanceFromPrice(fee, priceData: priceData)
        view?.didReceiveFeeViewModel(feeViewModel.value(for: selectedLocale))
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
        provideAssetVewModel()
        interactor.estimateFee()
    }

    func updateAmount(_ newValue: Decimal) {
        inputResult = .absolute(newValue)
        provideAssetVewModel()
        interactor.estimateFee()
    }

    func didTapBackButton() {
        router.dismiss(view: view)
    }

    func didTapContinueButton() {
        let inputAmount = inputResult?.absoluteValue(from: balanceMinusFee) ?? 0.0
        let spendingAmount = inputAmount.toSubstrateAmount(precision: Int16(chainAsset.asset.precision))
        DataValidationRunner(validators: [
            dataValidatingFactory.canNominate(
                amount: inputAmount,
                minimalBalance: minJoinBond,
                minNominatorBond: minJoinBond,
                locale: selectedLocale
            ),
            dataValidatingFactory.has(fee: fee, locale: selectedLocale, onError: { [weak self] in
                self?.interactor.estimateFee()
            }),
            dataValidatingFactory.canPayFeeAndAmount(
                balance: balance,
                fee: fee,
                spendingAmount: inputAmount,
                locale: selectedLocale
            ),
            dataValidatingFactory.exsitentialDepositIsNotViolated(
                spendingAmount: spendingAmount,
                totalAmount: totalAmount,
                minimumBalance: existentialDeposit,
                locale: selectedLocale,
                chainAsset: chainAsset,
                canProceedIfViolated: false
            )
        ]).runValidation { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.router.presentPoolsList(
                from: strongSelf.view,
                chainAsset: strongSelf.chainAsset,
                wallet: strongSelf.wallet,
                inputAmount: inputAmount
            )
        }
    }

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
    func didReceive(existentialDepositResult: Result<BigUInt, Error>) {
        switch existentialDepositResult {
        case let .success(existentialDeposit):
            self.existentialDeposit = existentialDeposit
        case let .failure(error):
            logger?.error(error.localizedDescription)
        }
    }

    func didReceivePriceData(result: Result<PriceData?, Error>) {
        switch result {
        case let .success(priceData):
            self.priceData = priceData

            provideAssetVewModel()
            provideInputViewModel()
            provideFeeViewModel()
        case let .failure(error):
            logger?.error("StakingPoolJoinConfigPresenter.didReceivePriceData.error: \(error)")
        }
    }

    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>) {
        switch result {
        case let .success(accountInfo):
            totalAmount = accountInfo?.data.available

            if let accountInfo = accountInfo {
                balance = Decimal.fromSubstrateAmount(
                    accountInfo.data.available,
                    precision: Int16(chainAsset.asset.precision)
                )
            } else {
                balance = Decimal.zero
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
            provideFeeViewModel()

            switch inputResult {
            case .rate:
                provideInputViewModel()
            default:
                break
            }

        case let .failure(error):
            logger?.error("StakingPoolJoinConfigPresenter.didReceiveFee.error: \(error)")
        }
    }

    func didReceiveMinBond(_ minJoinBond: BigUInt?) {
        guard let minJoinBond = minJoinBond else {
            return
        }

        self.minJoinBond = Decimal.fromSubstrateAmount(
            minJoinBond,
            precision: Int16(chainAsset.asset.precision)
        )
    }
}

// MARK: - Localizable

extension StakingPoolJoinConfigPresenter: Localizable {
    func applyLocalization() {
        provideFeeViewModel()
    }
}

extension StakingPoolJoinConfigPresenter: StakingPoolJoinConfigModuleInput {}
