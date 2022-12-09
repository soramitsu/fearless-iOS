import Foundation
import BigInt
import SoraFoundation
import IrohaCrypto

final class StakingRewardDestSetupPresenter {
    weak var view: StakingRewardDestSetupViewProtocol?

    let wireframe: StakingRewardDestSetupWireframeProtocol
    let interactor: StakingRewardDestSetupInteractorInputProtocol
    let rewardDestViewModelFactory: ChangeRewardDestinationViewModelFactoryProtocol
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let dataValidatingFactory: StakingDataValidatingFactoryProtocol
    let applicationConfig: ApplicationConfigProtocol
    let chain: ChainModel
    let asset: AssetModel
    let selectedAccount: MetaAccountModel
    let logger: LoggerProtocol?

    private var rewardDestination: RewardDestination<ChainAccountResponse>? {
        didSet {
            refreshFeeIfNeeded()
        }
    }

    private var calculator: RewardCalculatorEngineProtocol?
    private var originalDestination: RewardDestination<AccountAddress>?
    private var stashAccount: ChainAccountResponse?
    private var controllerAccount: ChainAccountResponse?
    private var priceData: PriceData?
    private var stashItem: StashItem?
    private var bonded: Decimal?
    private var balance: Decimal?
    private var fee: Decimal?
    private var nomination: Nomination?

    init(
        wireframe: StakingRewardDestSetupWireframeProtocol,
        interactor: StakingRewardDestSetupInteractorInputProtocol,
        rewardDestViewModelFactory: ChangeRewardDestinationViewModelFactoryProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        dataValidatingFactory: StakingDataValidatingFactoryProtocol,
        applicationConfig: ApplicationConfigProtocol,
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel,
        logger: LoggerProtocol? = nil
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.rewardDestViewModelFactory = rewardDestViewModelFactory
        self.balanceViewModelFactory = balanceViewModelFactory
        self.dataValidatingFactory = dataValidatingFactory
        self.applicationConfig = applicationConfig
        self.chain = chain
        self.asset = asset
        self.selectedAccount = selectedAccount
        self.logger = logger
    }

    // MARK: - Private functions

    private func refreshFeeIfNeeded() {
//        guard fee == nil else {
//            return
//        }

        if let rewardDestination = rewardDestination {
            interactor.estimateFee(rewardDestination: rewardDestination.accountAddress)
        }
    }

    private func provideRewardDestination() {
        guard
            let bonded = bonded,
            let calculator = calculator,
            let originalRewardDestination = originalDestination else {
            view?.didReceiveRewardDestination(viewModel: nil)
            return
        }

        let viewModel = rewardDestViewModelFactory.createViewModel(
            from: originalRewardDestination,
            selectedRewardDestination: rewardDestination,
            bondedAmount: bonded,
            calculator: calculator,
            nomination: nomination,
            priceData: priceData
        )

        view?.didReceiveRewardDestination(viewModel: viewModel)
    }

    private func provideFeeViewModel() {
        if let fee = fee {
            let feeViewModel = balanceViewModelFactory.balanceFromPrice(fee, priceData: priceData)
            view?.didReceiveFee(viewModel: feeViewModel)
        } else {
            view?.didReceiveFee(viewModel: nil)
        }
    }
}

extension StakingRewardDestSetupPresenter: StakingRewardDestSetupPresenterProtocol {
    func setup() {
        provideRewardDestination()
        provideFeeViewModel()

        interactor.setup()
    }

    func selectRestakeDestination() {
        rewardDestination = .restake
        provideRewardDestination()
    }

    func selectPayoutDestination() {
        if let stashAccount = stashAccount {
            rewardDestination = .payout(account: stashAccount)
        } else if let controller = controllerAccount {
            rewardDestination = .payout(account: controller)
        }

        provideRewardDestination()
    }

    func selectPayoutAccount() {
        interactor.fetchPayoutAccounts()

        refreshFeeIfNeeded()
    }

    func displayLearnMore() {
        if let view = view {
            wireframe.showWeb(
                url: applicationConfig.learnPayoutURL,
                from: view,
                style: .automatic
            )
        }
    }

    func proceed() {
        let locale = view?.localizationManager?.selectedLocale ?? Locale.current
        DataValidationRunner(validators: [
            dataValidatingFactory.has(
                controller: controllerAccount,
                for: stashItem?.controller ?? "",
                locale: locale
            ),

            dataValidatingFactory.has(fee: fee, locale: locale, onError: { [weak self] in
                self?.refreshFeeIfNeeded()
            }),

            dataValidatingFactory.canPayFee(balance: balance, fee: fee, locale: locale)

        ]).runValidation { [weak self] in
            guard let self = self, let rewardDestination = self.rewardDestination else { return }

            self.wireframe.proceed(
                view: self.view,
                rewardDestination: rewardDestination,
                asset: self.asset,
                chain: self.chain,
                selectedAccount: self.selectedAccount
            )
        }
    }
}

extension StakingRewardDestSetupPresenter: ModalPickerViewControllerDelegate {
    func modalPickerDidSelectModelAtIndex(_ index: Int, context: AnyObject?) {
        guard
            let accounts =
            (context as? PrimitiveContextWrapper<[ChainAccountResponse]>)?.value
        else {
            return
        }

        rewardDestination = .payout(account: accounts[index])

        provideRewardDestination()
    }
}

extension StakingRewardDestSetupPresenter: StakingRewardDestSetupInteractorOutputProtocol {
    func didReceivePriceData(result: Result<PriceData?, Error>) {
        switch result {
        case let .success(priceData):
            self.priceData = priceData
            provideFeeViewModel()

        case let .failure(error):
            logger?.error("Price data subscription error: \(error)")
        }
    }

    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>) {
        switch result {
        case let .success(dispatchInfo):
            if let fee = BigUInt(dispatchInfo.fee) {
                self.fee = Decimal.fromSubstrateAmount(fee, precision: Int16(asset.precision))
            }

            provideFeeViewModel()
        case let .failure(error):
            logger?.error("Did receive fee error: \(error)")
        }
    }

    func didReceiveStashItem(result: Result<StashItem?, Error>) {
        switch result {
        case let .success(stashItem):
            self.stashItem = stashItem
        case let .failure(error):
            logger?.error("Did receive stash item error: \(error)")
        }
    }

    func didReceiveController(result: Result<ChainAccountResponse?, Error>) {
        switch result {
        case let .success(account):
            controllerAccount = account
        case let .failure(error):
            logger?.error("Did receive controller account error: \(error)")
        }
    }

    func didReceiveStash(result: Result<ChainAccountResponse?, Error>) {
        switch result {
        case let .success(account):
            stashAccount = account
        case let .failure(error):
            logger?.error("Did receive controller account error: \(error)")
        }
    }

    func didReceiveStakingLedger(result: Result<StakingLedger?, Error>) {
        switch result {
        case let .success(stakingLedger):
            bonded = stakingLedger.map {
                Decimal.fromSubstrateAmount($0.active, precision: Int16(asset.precision))
            } ?? nil

            provideRewardDestination()
        case let .failure(error):
            logger?.error("Staking ledger subscription error: \(error)")
        }
    }

    func didReceiveRewardDestinationAccount(result: Result<RewardDestination<ChainAccountResponse>?, Error>) {
        switch result {
        case let .success(rewardDestination):
            if self.rewardDestination == nil {
                self.rewardDestination = rewardDestination
            }

            originalDestination = rewardDestination?.accountAddress

            provideRewardDestination()
        case let .failure(error):
            logger?.error("Reward destination account error: \(error)")
        }
    }

    func didReceiveRewardDestinationAddress(result: Result<RewardDestination<AccountAddress>?, Error>) {
        switch result {
        case let .success(rewardDestination):
            originalDestination = rewardDestination

            provideRewardDestination()
        case let .failure(error):
            logger?.error("Reward destination account error: \(error)")
        }
    }

    func didReceiveCalculator(result: Result<RewardCalculatorEngineProtocol?, Error>) {
        switch result {
        case let .success(calculator):
            self.calculator = calculator

            provideRewardDestination()
        case let .failure(error):
            logger?.error("Did receive calculator error: \(error)")
        }
    }

    func didReceiveAccounts(result: Result<[ChainAccountResponse], Error>) {
        switch result {
        case let .success(accounts):
            let context = PrimitiveContextWrapper(value: accounts)

            let title = LocalizableResource { locale in
                R.string.localizable
                    .stakingRewardPayoutAccount(preferredLanguages: locale.rLanguages)
            }

            wireframe.presentAccountSelection(
                accounts,
                selectedAccountItem: rewardDestination?.payoutAccount,
                title: title,
                delegate: self,
                from: view,
                context: context
            )

        case let .failure(error):
            logger?.error("Did receive accounts retrieval error: \(error)")
        }
    }

    func didReceiveNomination(result: Result<Nomination?, Error>) {
        switch result {
        case let .success(nomination):
            self.nomination = nomination

            provideRewardDestination()
        case let .failure(error):
            logger?.error("Nomination error: \(error)")
        }
    }

    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>) {
        switch result {
        case let .success(accountInfo):
            balance = accountInfo.map {
                Decimal.fromSubstrateAmount($0.data.stakingAvailable, precision: Int16(asset.precision))
            } ?? nil
        case let .failure(error):
            logger?.error("Account info error: \(error)")
        }
    }
}
