import Foundation

final class YourValidatorListRelaychainViewModelState: YourValidatorListViewModelState {
    var stateListener: YourValidatorListModelStateListener?

    let chainAsset: ChainAsset
    let wallet: MetaAccountModel
    let logger: LoggerProtocol?
    var locale: Locale?

    private(set) var validatorsModel: YourValidatorsModel?
    private var stashItem: StashItem?
    private var ledger: StakingLedger?
    private var controllerAccount: ChainAccountResponse?
    private var rewardDestinationArg: RewardDestinationArg?
    private var lastError: Error?

    init(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        logger: LoggerProtocol? = nil
    ) {
        self.chainAsset = chainAsset
        self.wallet = wallet
        self.logger = logger
    }

    func setStateListener(_ stateListener: YourValidatorListModelStateListener?) {
        self.stateListener = stateListener
    }

    func validatorInfoFlow(address: String) -> ValidatorInfoFlow? {
        guard let validatorInfo = validatorsModel?.allValidators
            .first(where: { $0.address == address }) else {
            return nil
        }

        return .relaychain(validatorInfo: validatorInfo, address: nil)
    }

    func selectValidatorsStartFlow() -> SelectValidatorsStartFlow? {
        guard
            let bondedAmount = ledger?.active,
            let rewardDestination = rewardDestinationArg,
            let stashItem = stashItem else {
            return nil
        }

        guard let controllerAccount = controllerAccount else {
            stateListener?.handleControllerAccountMissing(stashItem.controller)
            return nil
        }

        guard
            let amount = Decimal.fromSubstrateAmount(
                bondedAmount,
                precision: Int16(chainAsset.asset.precision)
            ),
            let rewardDestination = try? RewardDestination(
                payee: rewardDestination,
                stashItem: stashItem,
                chainFormat: chainAsset.chain.chainFormat
            ) else {
            return nil
        }

        let selectedTargets = validatorsModel.map {
            !$0.pendingValidators.isEmpty ? $0.pendingValidators : $0.currentValidators
        }

        let existingBonding = ExistingBonding(
            stashAddress: stashItem.stash,
            controllerAccount: controllerAccount,
            amount: amount,
            rewardDestination: rewardDestination,
            selectedTargets: selectedTargets
        )

        return .relaychainExisting(state: existingBonding)
    }

    func resetState() {
        validatorsModel = nil
        lastError = nil
    }

    func changeLocale(_ locale: Locale) {
        self.locale = locale
    }

    private func handle(error: Error) {
        lastError = error
        validatorsModel = nil

        updateView()
    }

    private func handle(validatorsModel: YourValidatorsModel?) {
        self.validatorsModel = validatorsModel
        lastError = nil

        updateView()
    }

    private func updateView() {
        guard lastError == nil else {
            let locale = locale ?? Locale.current
            let errorDescription = R.string.localizable
                .commonErrorNoDataRetrieved(preferredLanguages: locale.rLanguages)
            stateListener?.didReceiveState(.error(errorDescription))
            return
        }

        guard validatorsModel != nil else {
            stateListener?.didReceiveState(.loading)
            return
        }

        stateListener?.modelStateDidChanged(viewModelState: self)
    }
}

extension YourValidatorListRelaychainViewModelState: YourValidatorListRelaychainStrategyOutput {
    func didReceiveController(result: Result<ChainAccountResponse?, Error>) {
        switch result {
        case let .success(item):
            controllerAccount = item
        case let .failure(error):
            handle(error: error)
        }
    }

    func didReceiveValidators(result: Result<YourValidatorsModel?, Error>) {
        switch result {
        case let .success(item):
            handle(validatorsModel: item)
        case let .failure(error):
            handle(error: error)
        }
    }

    func didReceiveStashItem(result: Result<StashItem?, Error>) {
        switch result {
        case let .success(item):
            stashItem = item
        case let .failure(error):
            handle(error: error)
        }
    }

    func didReceiveLedger(result: Result<StakingLedger?, Error>) {
        switch result {
        case let .success(item):
            ledger = item
        case let .failure(error):
            handle(error: error)
        }
    }

    func didReceiveRewardDestination(result: Result<RewardDestinationArg?, Error>) {
        switch result {
        case let .success(item):
            rewardDestinationArg = item
        case let .failure(error):
            handle(error: error)
        }
    }
}
