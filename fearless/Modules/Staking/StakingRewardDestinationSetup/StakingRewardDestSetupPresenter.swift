import Foundation
import BigInt
import SoraFoundation
import IrohaCrypto

final class StakingRewardDestSetupPresenter {
    weak var view: StakingRewardDestSetupViewProtocol?

    let wireframe: StakingRewardDestSetupWireframeProtocol
    let interactor: StakingRewardDestSetupInteractorInputProtocol
    let rewardDestViewModelFactory: RewardDestinationViewModelFactoryProtocol
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let dataValidatingFactory: StakingDataValidatingFactoryProtocol
    let applicationConfig: ApplicationConfigProtocol
    let chain: Chain
    let logger: LoggerProtocol?

    private var rewardDestination: RewardDestination<AccountItem>?
    private var calculator: RewardCalculatorEngineProtocol?
    private var electionStatus: ElectionStatus?
    private var originalDestination: RewardDestination<AccountAddress>?
    private var stashAccount: AccountItem?
    private var controllerAccount: AccountItem?
    private var priceData: PriceData?
    private var stashItem: StashItem?
    private var bonded: Decimal?
    private var balance: Decimal?
    private var fee: Decimal?
    private var nomination: Nomination?

    init(
        wireframe: StakingRewardDestSetupWireframeProtocol,
        interactor: StakingRewardDestSetupInteractorInputProtocol,
        rewardDestViewModelFactory: RewardDestinationViewModelFactoryProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        dataValidatingFactory: StakingDataValidatingFactoryProtocol,
        applicationConfig: ApplicationConfigProtocol,
        chain: Chain,
        logger: LoggerProtocol? = nil
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.rewardDestViewModelFactory = rewardDestViewModelFactory
        self.balanceViewModelFactory = balanceViewModelFactory
        self.dataValidatingFactory = dataValidatingFactory
        self.applicationConfig = applicationConfig
        self.chain = chain
        self.logger = logger
    }

    // MARK: - Private functions

    private func refreshFeeIfNeeded() {
        guard fee == nil else {
            return
        }

        interactor.estimateFee()
    }

    private func createRewardDestinationViewModelForReward(
        _ reward: CalculatedReward
    ) throws -> LocalizableResource<RewardDestinationViewModelProtocol>? {
        if let rewardDestination = rewardDestination {
            switch rewardDestination {
            case .restake:
                return rewardDestViewModelFactory.createRestake(from: reward, priceData: priceData)
            case let .payout(account):
                return try rewardDestViewModelFactory
                    .createPayout(from: reward, priceData: priceData, account: account)
            }
        }

        if let originalDestination = originalDestination {
            switch originalDestination {
            case .restake:
                return rewardDestViewModelFactory.createRestake(from: reward, priceData: priceData)
            case let .payout(address):
                return try rewardDestViewModelFactory
                    .createPayout(from: reward, priceData: priceData, address: address)
            }
        }

        return nil
    }

    private func createRewardDestinationViewModelForValidatorId(
        _ validatorId: AccountId,
        bonded: Decimal,
        calculator: RewardCalculatorEngineProtocol
    ) throws -> LocalizableResource<RewardDestinationViewModelProtocol>? {
        let restakeReturn = try calculator.calculateValidatorReturn(
            validatorAccountId: validatorId,
            isCompound: true,
            period: .year
        )

        let payoutReturn = try calculator.calculateValidatorReturn(
            validatorAccountId: validatorId,
            isCompound: false,
            period: .year
        )

        let reward = CalculatedReward(
            restakeReturn: restakeReturn * bonded,
            restakeReturnPercentage: restakeReturn,
            payoutReturn: payoutReturn * bonded,
            payoutReturnPercentage: payoutReturn
        )

        return try createRewardDestinationViewModelForReward(reward)
    }

    private func createMaxReturnRewardDestinationViewModel(
        for bonded: Decimal,
        calculator: RewardCalculatorEngineProtocol
    ) throws -> LocalizableResource<RewardDestinationViewModelProtocol>? {
        let restakeReturn = calculator.calculateMaxReturn(isCompound: true, period: .year)

        let payoutReturn = calculator.calculateMaxReturn(isCompound: false, period: .year)

        let reward = CalculatedReward(
            restakeReturn: restakeReturn * bonded,
            restakeReturnPercentage: restakeReturn,
            payoutReturn: payoutReturn * bonded,
            payoutReturnPercentage: payoutReturn
        )

        return try createRewardDestinationViewModelForReward(reward)
    }

    private func createRewardDestinationViewModelFromNomination(
        _ nomination: Nomination,
        bonded: Decimal,
        using calculator: RewardCalculatorEngineProtocol
    ) throws -> LocalizableResource<RewardDestinationViewModelProtocol>? {
        let (maxTarget, _): (AccountId?, Decimal?) = nomination.targets
            .reduce((nil, nil)) { result, target in
                let targetReturn = try? calculator.calculateValidatorReturn(
                    validatorAccountId: target,
                    isCompound: false,
                    period: .year
                )

                guard let oldReturn = result.1 else {
                    return targetReturn != nil ? (target, targetReturn) : result
                }

                return targetReturn.map { $0 > oldReturn ? (target, $0) : result } ?? result
            }

        if let target = maxTarget {
            return try createRewardDestinationViewModelForValidatorId(
                target,
                bonded: bonded,
                calculator: calculator
            )
        } else {
            return try createMaxReturnRewardDestinationViewModel(
                for: bonded,
                calculator: calculator
            )
        }
    }

    private func provideRewardDestination() {
        guard let bonded = bonded, let calculator = calculator else {
            view?.didReceiveRewardDestination(viewModel: nil)
            return
        }

        let maybeRewardDestinationViewModel: LocalizableResource<RewardDestinationViewModelProtocol>? = {
            if let nomination = nomination {
                return try? createRewardDestinationViewModelFromNomination(
                    nomination,
                    bonded: bonded,
                    using: calculator
                )
            }

            return try? createMaxReturnRewardDestinationViewModel(for: bonded, calculator: calculator)
        }()

        guard let selectionViewModel = maybeRewardDestinationViewModel else {
            view?.didReceiveRewardDestination(viewModel: nil)
            return
        }

        let alreadyApplied = rewardDestination == nil || (rewardDestination?.accountAddress == originalDestination)

        let viewModel = ChangeRewardDestinationViewModel(
            selectionViewModel: selectionViewModel,
            canApply: !alreadyApplied
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
            dataValidatingFactory.has(fee: fee, locale: locale, onError: { [weak self] in
                self?.refreshFeeIfNeeded()
            }),

            dataValidatingFactory.has(
                controller: controllerAccount,
                for: stashItem?.controller ?? "",
                locale: locale
            ),

            dataValidatingFactory.canPayFee(balance: balance, fee: fee, locale: locale),

            dataValidatingFactory.electionClosed(electionStatus, locale: locale)

        ]).runValidation { [weak self] in
            guard let rewardDestination = self?.rewardDestination else { return }

            self?.wireframe.proceed(
                view: self?.view,
                rewardDestination: rewardDestination
            )
        }
    }
}

extension StakingRewardDestSetupPresenter: ModalPickerViewControllerDelegate {
    func modalPickerDidSelectModelAtIndex(_ index: Int, context: AnyObject?) {
        guard
            let accounts =
            (context as? PrimitiveContextWrapper<[AccountItem]>)?.value
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
                self.fee = Decimal.fromSubstrateAmount(fee, precision: chain.addressType.precision)
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

    func didReceiveController(result: Result<AccountItem?, Error>) {
        switch result {
        case let .success(account):
            controllerAccount = account
        case let .failure(error):
            logger?.error("Did receive controller account error: \(error)")
        }
    }

    func didReceiveStash(result: Result<AccountItem?, Error>) {
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
                Decimal.fromSubstrateAmount($0.active, precision: chain.addressType.precision)
            } ?? nil

            provideRewardDestination()
        case let .failure(error):
            logger?.error("Staking ledger subscription error: \(error)")
        }
    }

    func didReceiveRewardDestinationAccount(result: Result<RewardDestination<AccountItem>?, Error>) {
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

    func didReceiveAccounts(result: Result<[AccountItem], Error>) {
        switch result {
        case let .success(accounts):
            let context = PrimitiveContextWrapper(value: accounts)

            let title = LocalizableResource { locale in
                R.string.localizable
                    .stakingRewardDestinationTitle(preferredLanguages: locale.rLanguages)
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

    func didReceiveElectionStatus(result: Result<ElectionStatus?, Error>) {
        switch result {
        case let .success(electionStatus):
            self.electionStatus = electionStatus
        case let .failure(error):
            logger?.error("Election status error: \(error)")
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
                Decimal.fromSubstrateAmount($0.data.available, precision: chain.addressType.precision)
            } ?? nil
        case let .failure(error):
            logger?.error("Account info error: \(error)")
        }
    }
}
