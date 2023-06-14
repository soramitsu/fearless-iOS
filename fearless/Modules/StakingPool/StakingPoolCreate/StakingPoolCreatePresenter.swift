import Foundation
import SoraFoundation
import BigInt
import SSFModels

struct StakingPoolCreateData {
    let poolId: UInt32
    let poolName: String
    let amount: Decimal
    let root: MetaAccountModel
    let nominator: MetaAccountModel
    let bouncer: MetaAccountModel
    let chainAsset: ChainAsset
}

final class StakingPoolCreatePresenter {
    // MARK: Private properties

    private weak var view: StakingPoolCreateViewInput?
    private let router: StakingPoolCreateRouterInput
    private let interactor: StakingPoolCreateInteractorInput

    private let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    private let viewModelFactory: StakingPoolCreateViewModelFactoryProtocol
    private let dataValidatingFactory: StakingDataValidatingFactoryProtocol
    private let logger: LoggerProtocol
    private let wallet: MetaAccountModel
    private let chainAsset: ChainAsset

    private var totalAmount: BigUInt?
    private var inputResult: AmountInputResult?
    private var priceData: PriceData?
    private var balance: Decimal?
    private var fee: Decimal?
    private var balanceMinusFee: Decimal { (balance ?? 0) - (fee ?? 0) - (existentialDeposit ?? 0) }
    private var minCreateBond: Decimal?
    private var nominatorWallet: MetaAccountModel
    private var bouncerWallet: MetaAccountModel
    private var rootWallet: MetaAccountModel
    private var lastPoolId: UInt32?
    private var poolNameInputViewModel: InputViewModelProtocol
    private var existentialDeposit: Decimal?

    // MARK: - Constructors

    init(
        interactor: StakingPoolCreateInteractorInput,
        router: StakingPoolCreateRouterInput,
        localizationManager: LocalizationManagerProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        viewModelFactory: StakingPoolCreateViewModelFactoryProtocol,
        dataValidatingFactory: StakingDataValidatingFactoryProtocol,
        logger: LoggerProtocol,
        wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        amount: Decimal?
    ) {
        self.interactor = interactor
        self.router = router
        self.balanceViewModelFactory = balanceViewModelFactory
        self.viewModelFactory = viewModelFactory
        self.dataValidatingFactory = dataValidatingFactory
        self.logger = logger
        self.wallet = wallet
        self.chainAsset = chainAsset
        nominatorWallet = wallet
        bouncerWallet = wallet
        rootWallet = wallet

        let nameInputHandling = InputHandler(predicate: NSPredicate.notEmpty)
        poolNameInputViewModel = InputViewModel(inputHandler: nameInputHandling)

        if let amount = amount {
            inputResult = .absolute(amount)
        }

        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func provideViewModel() {
        let viewModel = viewModelFactory.buildViewModel(
            wallet: wallet,
            nominatorWallet: nominatorWallet,
            bouncer: bouncerWallet,
            rootWallet: rootWallet,
            lastPoolId: lastPoolId
        )
        view?.didReceiveViewModel(viewModel)
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

        let feeViewModel = balanceViewModelFactory.balanceFromPrice(fee, priceData: priceData, usageCase: .detailsCrypto)
        view?.didReceiveFeeViewModel(feeViewModel.value(for: selectedLocale))
    }

    private func provideInputViewModel() {
        let inputAmount = inputResult?.absoluteValue(from: balanceMinusFee)

        let inputViewModel = balanceViewModelFactory.createBalanceInputViewModel(inputAmount)
            .value(for: selectedLocale)

        view?.didReceiveAmountInputViewModel(inputViewModel)
    }

    private func presentAlert() {
        let languages = localizationManager?.selectedLocale.rLanguages

        let action = SheetAlertPresentableAction(
            title: R.string.localizable.commonCancelOperationAction(preferredLanguages: languages),
            button: UIFactory.default.createDestructiveButton()
        ) { [weak self] in
            self?.router.dismiss(view: self?.view)
        }

        let viewModel = SheetAlertPresentableViewModel(
            title: R.string.localizable.stakingPoolCreateMissingNameTitle(preferredLanguages: languages),
            message: nil,
            actions: [action],
            closeAction: nil,
            icon: R.image.iconWarningBig()
        )

        DispatchQueue.main.async { [weak self] in
            self?.router.present(viewModel: viewModel, from: self?.view)
        }
    }

    private func refreshFee() {
        let inputAmount = inputResult?.absoluteValue(from: balanceMinusFee) ?? 0.0
        let spendingAmount = inputAmount.toSubstrateAmount(precision: Int16(chainAsset.asset.precision))
        let poolName = poolNameInputViewModel.inputHandler.value

        interactor.estimateFee(amount: spendingAmount, poolName: poolName, poolId: lastPoolId)
    }
}

// MARK: - StakingPoolCreateViewOutput

// swiftlint:disable function_body_length
extension StakingPoolCreatePresenter: StakingPoolCreateViewOutput {
    func createDidTapped() {
        let precision = Int16(chainAsset.asset.precision)
        let inputAmount = inputResult?.absoluteValue(from: balanceMinusFee) ?? 0.0
        let spendingAmount = inputAmount.toSubstrateAmount(precision: precision)
        let existentialDepositAmount = existentialDeposit?.toSubstrateAmount(precision: precision)

        DataValidationRunner(validators: [
            dataValidatingFactory.canNominate(
                amount: inputAmount,
                minimalBalance: minCreateBond,
                minNominatorBond: minCreateBond,
                locale: selectedLocale
            ),
            dataValidatingFactory.has(
                fee: fee,
                locale: selectedLocale,
                onError: { [weak self] in
                    self?.refreshFee()
                }
            ),
            dataValidatingFactory.canPayFeeAndAmount(
                balance: balance,
                fee: fee,
                spendingAmount: inputAmount,
                locale: selectedLocale
            ),
            dataValidatingFactory.createPoolName(
                complite: poolNameInputViewModel.inputHandler.completed,
                locale: selectedLocale
            ),
            dataValidatingFactory.exsitentialDepositIsNotViolated(
                spendingAmount: spendingAmount,
                totalAmount: totalAmount,
                minimumBalance: existentialDepositAmount,
                locale: selectedLocale,
                chainAsset: chainAsset
            )
        ]).runValidation { [weak self] in
            guard
                let strongSelf = self,
                let lastPoolId = strongSelf.lastPoolId
            else {
                return
            }

            let createData = StakingPoolCreateData(
                poolId: lastPoolId + 1,
                poolName: strongSelf.poolNameInputViewModel.inputHandler.value,
                amount: inputAmount,
                root: strongSelf.wallet,
                nominator: strongSelf.nominatorWallet,
                bouncer: strongSelf.bouncerWallet,
                chainAsset: strongSelf.chainAsset
            )

            strongSelf.router.showConfirm(from: strongSelf.view, with: createData)
        }
    }

    func nominatorDidTapped() {
        router.showWalletManagment(
            contextTag: StakingPoolCreateContextTag.nominator.rawValue,
            from: view,
            moduleOutput: self
        )
    }

    func bouncerDidTapped() {
        router.showWalletManagment(
            contextTag: StakingPoolCreateContextTag.bouncer.rawValue,
            from: view,
            moduleOutput: self
        )
    }

    func selectAmountPercentage(_ percentage: Float) {
        inputResult = .rate(Decimal(Double(percentage)))
        provideAssetVewModel()
        provideInputViewModel()

        refreshFee()
    }

    func updateAmount(_ newValue: Decimal) {
        inputResult = .absolute(newValue)
        provideAssetVewModel()

        refreshFee()
    }

    func didLoad(view: StakingPoolCreateViewInput) {
        self.view = view
        interactor.setup(with: self)
        refreshFee()
        provideViewModel()
        provideInputViewModel()

        view.didReceive(nameViewModel: poolNameInputViewModel)
    }

    func backDidTapped() {
        router.dismiss(view: view)
    }

    func nameTextFieldInputValueChanged() {
        refreshFee()
    }

    func rootDidTapped() {
        router.showWalletManagment(
            contextTag: StakingPoolCreateContextTag.root.rawValue,
            from: view,
            moduleOutput: self
        )
    }
}

// MARK: - StakingPoolCreateInteractorOutput

extension StakingPoolCreatePresenter: StakingPoolCreateInteractorOutput {
    func didReceive(existentialDepositResult: Result<BigUInt, Error>) {
        switch existentialDepositResult {
        case let .success(existentialDeposit):
            self.existentialDeposit = Decimal.fromSubstrateAmount(
                existentialDeposit,
                precision: Int16(chainAsset.asset.precision)
            )

            refreshFee()
        case let .failure(error):
            logger.error(error.localizedDescription)
        }
    }

    func didReceiveLastPoolId(_ lastPoolId: UInt32?) {
        self.lastPoolId = lastPoolId
        provideViewModel()

        refreshFee()
    }

    func didReceivePoolMember(_ poolMember: StakingPoolMember?) {
        if poolMember != nil {
            presentAlert()
        }
    }

    func didReceiveMinBond(_ minCreateBond: BigUInt?) {
        guard let minCreateBond = minCreateBond else {
            return
        }

        self.minCreateBond = Decimal.fromSubstrateAmount(
            minCreateBond,
            precision: Int16(chainAsset.asset.precision)
        )
    }

    func didReceivePriceData(result: Result<PriceData?, Error>) {
        switch result {
        case let .success(priceData):
            self.priceData = priceData

            provideAssetVewModel()
            provideInputViewModel()
            provideFeeViewModel()
        case let .failure(error):
            logger.error("error: \(error)")
        }
    }

    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>) {
        switch result {
        case let .success(accountInfo):
            totalAmount = accountInfo?.data.stakingAvailable
            if let accountInfo = accountInfo {
                balance = Decimal.fromSubstrateAmount(
                    accountInfo.data.stakingAvailable,
                    precision: Int16(chainAsset.asset.precision)
                )
            } else {
                balance = Decimal.zero
            }

            provideAssetVewModel()
        case let .failure(error):
            logger.error("error: \(error)")
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
            logger.error("error: \(error)")
        }
    }
}

// MARK: - Localizable

extension StakingPoolCreatePresenter: Localizable {
    func applyLocalization() {
        provideAssetVewModel()
        provideInputViewModel()
        provideFeeViewModel()
    }
}

extension StakingPoolCreatePresenter: StakingPoolCreateModuleInput {}

extension StakingPoolCreatePresenter: WalletsManagmentModuleOutput {
    private enum StakingPoolCreateContextTag: Int {
        case nominator = 0
        case bouncer
        case root
    }

    func selectedWallet(_ wallet: MetaAccountModel, for contextTag: Int) {
        guard let contextTag = StakingPoolCreateContextTag(rawValue: contextTag) else {
            return
        }

        switch contextTag {
        case .nominator:
            nominatorWallet = wallet
        case .bouncer:
            bouncerWallet = wallet
        case .root:
            rootWallet = wallet
        }

        provideViewModel()
    }
}
