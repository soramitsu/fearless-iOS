import Foundation

final class YourValidatorListPoolViewModelState: YourValidatorListViewModelState {
    var stateListener: YourValidatorListModelStateListener?
    private let chainAsset: ChainAsset
    private let wallet: MetaAccountModel
    private var stakingPool: StakingPool?
    private var palletId: Data?
    private var stakeInfo: StakingPoolMember?
    private var nomination: Nomination?
    private(set) var validatorsModel: YourValidatorsModel?
    var locale: Locale?

    init(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel
    ) {
        self.chainAsset = chainAsset
        self.wallet = wallet
    }

    func setStateListener(_ stateListener: YourValidatorListModelStateListener?) {
        self.stateListener = stateListener
    }

    func selectValidatorsStartFlow() -> SelectValidatorsStartFlow? {
        guard let stashAddress = try? fetchPoolAccount(for: .stash)?.toAddress(using: chainAsset.chain.chainFormat),
              let rewardAddress = try? fetchPoolAccount(for: .rewards)?.toAddress(using: chainAsset.chain.chainFormat),
              let amount = stakeInfo?.points,
              let amountDecimal = Decimal.fromSubstrateAmount(amount, precision: Int16(chainAsset.asset.precision)),
              let controller = wallet.fetch(for: chainAsset.chain.accountRequest())
        else {
            return nil
        }

        let selectedTargets = validatorsModel.map {
            !$0.pendingValidators.isEmpty ? $0.pendingValidators : $0.currentValidators
        }

        guard let poolId = stakingPool?.id,
              let poolIdValue = UInt32(poolId)
        else {
            return nil
        }

        let bonding = ExistingBonding(
            stashAddress: stashAddress,
            controllerAccount: controller,
            amount: amountDecimal,
            rewardDestination: .payout(account: rewardAddress),
            selectedTargets: selectedTargets
        )

        return .poolExisting(poolId: poolIdValue, state: bonding)
    }

    func validatorInfoFlow(address: String) -> ValidatorInfoFlow? {
        guard let validatorInfo = validatorsModel?.allValidators
            .first(where: { $0.address == address }) else {
            return nil
        }

        return .relaychain(validatorInfo: validatorInfo, address: nil)
    }

    func resetState() {
        validatorsModel = nil
    }

    func changeLocale(_ locale: Locale) {
        self.locale = locale
    }

    private func fetchPoolAccount(for type: PoolAccount) -> AccountId? {
        guard
            let modPrefix = "modl".data(using: .utf8),
            let palletIdData = palletId,
            let poolId = stakingPool?.id,
            let poolIdUintValue = UInt(poolId)
        else {
            return nil
        }

        var index: UInt8 = type.rawValue
        var poolIdValue = poolIdUintValue
        let indexData = Data(
            bytes: &index,
            count: MemoryLayout.size(ofValue: index)
        )

        let poolIdSize = MemoryLayout.size(ofValue: poolIdValue)
        let poolIdData = Data(
            bytes: &poolIdValue,
            count: poolIdSize
        )

        let emptyH256 = [UInt8](repeating: 0, count: 32)
        let poolAccountId = modPrefix + palletIdData + indexData + poolIdData + emptyH256

        return poolAccountId[0 ... 31]
    }
}

extension YourValidatorListPoolViewModelState: YourValidatorListPoolStrategyOutput {
    func didReceiveValidators(result: Result<YourValidatorsModel, Error>) {
        switch result {
        case let .success(validators):
            validatorsModel = validators
            stateListener?.modelStateDidChanged(viewModelState: self)
        case let .failure(error):
            stateListener?.didReceiveError(error: error)
        }
    }

    func didReceive(nomination: Nomination?) {
        self.nomination = nomination
    }

    func didReceive(stakeInfo: StakingPoolMember?) {
        self.stakeInfo = stakeInfo
    }

    func didReceive(stakingPool: StakingPool?) {
        self.stakingPool = stakingPool
    }

    func didReceive(error: Error) {
        stateListener?.didReceiveError(error: error)
    }

    func didReceive(palletIdResult: Result<Data, Error>) {
        switch palletIdResult {
        case let .success(palletId):
            self.palletId = palletId
        case let .failure(error):
            stateListener?.didReceiveError(error: error)
        }
    }
}
