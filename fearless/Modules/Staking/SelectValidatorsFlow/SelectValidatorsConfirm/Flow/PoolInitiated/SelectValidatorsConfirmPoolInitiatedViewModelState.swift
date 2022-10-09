import Foundation
import RobinHood
import BigInt

// swiftlint:disable type_name
final class SelectValidatorsConfirmPoolInitiatedViewModelState: SelectValidatorsConfirmViewModelState {
    var amount: Decimal? { initiatedBonding.amount }
    let poolId: UInt32
    var stateListener: SelectValidatorsConfirmModelStateListener?
    let targets: [SelectedValidatorInfo]
    let maxTargets: Int
    let initiatedBonding: InitiatedBonding
    let chainAsset: ChainAsset
    let wallet: MetaAccountModel
    let dataValidatingFactory: StakingDataValidatingFactoryProtocol

    private(set) var confirmationModel: SelectValidatorsConfirmRelaychainModel?
    private(set) var priceData: PriceData?
    private(set) var fee: Decimal?
    private(set) var minimalBalance: Decimal?
    private(set) var minNominatorBond: Decimal?
    private(set) var counterForNominators: UInt32?
    private(set) var maxNominatorsCount: UInt32?
    private(set) var stakingDuration: StakingDuration?

    var payoutAccountAddress: String? {
        initiatedBonding.rewardDestination.payoutAccount?.toAddress()
    }

    var walletAccountAddress: String? {
        wallet.fetch(for: chainAsset.chain.accountRequest())?.toAddress()
    }

    init(
        poolId: UInt32,
        targets: [SelectedValidatorInfo],
        maxTargets: Int,
        initiatedBonding: InitiatedBonding,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        dataValidatingFactory: StakingDataValidatingFactoryProtocol
    ) {
        self.poolId = poolId
        self.targets = targets
        self.maxTargets = maxTargets
        self.initiatedBonding = initiatedBonding
        self.chainAsset = chainAsset
        self.wallet = wallet
        self.dataValidatingFactory = dataValidatingFactory
    }

    func setStateListener(_ stateListener: SelectValidatorsConfirmModelStateListener?) {
        self.stateListener = stateListener
    }

    func validators(using locale: Locale) -> [DataValidating] {
        [
            dataValidatingFactory.canNominate(
                amount: initiatedBonding.amount,
                minimalBalance: minimalBalance,
                minNominatorBond: minNominatorBond,
                locale: locale
            ),
            dataValidatingFactory.maxNominatorsCountNotApplied(
                counterForNominators: counterForNominators,
                maxNominatorsCount: maxNominatorsCount,
                hasExistingNomination: false,
                locale: locale
            )
        ]
    }

    func createExtrinsicBuilderClosure() -> ExtrinsicBuilderClosure? {
        let targets = targets
        let poolId = poolId

        let closure: ExtrinsicBuilderClosure = { builder in
            let callFactory = SubstrateCallFactory()

            let nominateCall = try callFactory.poolNominate(poolId: poolId, targets: targets)

            return try builder
                .adding(call: nominateCall)
        }

        return closure
    }

    private func provideInitiatedBondingConfirmationModel() {
        let rewardDestination: RewardDestination<DisplayAddress> = {
            switch initiatedBonding.rewardDestination {
            case .restake:
                return .restake
            case let .payout(account):
                let displayAddress = DisplayAddress(
                    address: account.toAddress() ?? "",
                    username: account.name
                )
                return .payout(account: displayAddress)
            }
        }()

        let stash = DisplayAddress(
            address: wallet.fetch(for: chainAsset.chain.accountRequest())?.toAddress() ?? "",
            username: wallet.name
        )

        confirmationModel = SelectValidatorsConfirmRelaychainModel(
            wallet: stash,
            amount: initiatedBonding.amount,
            rewardDestination: rewardDestination,
            targets: targets,
            maxTargets: maxTargets,
            hasExistingBond: false,
            hasExistingNomination: false
        )

        stateListener?.provideConfirmationState(viewModelState: self)
    }
}

extension SelectValidatorsConfirmPoolInitiatedViewModelState: SelectValidatorsConfirmPoolInitiatedStrategyOutput {
    func didSetup() {
        provideInitiatedBondingConfirmationModel()
    }

    func didReceiveMinBond(result: Result<BigUInt?, Error>) {
        switch result {
        case let .success(minBond):
            minNominatorBond = minBond.map {
                Decimal.fromSubstrateAmount($0, precision: Int16(chainAsset.asset.precision))
            } ?? nil
        case let .failure(error):
            stateListener?.didReceiveError(error: error)
        }
    }

    func didReceiveMaxNominatorsCount(result: Result<UInt32?, Error>) {
        switch result {
        case let .success(maxNominatorsCount):
            self.maxNominatorsCount = maxNominatorsCount
        case let .failure(error):
            stateListener?.didReceiveError(error: error)
        }
    }

    func didReceiveCounterForNominators(result: Result<UInt32?, Error>) {
        switch result {
        case let .success(counterForNominators):
            self.counterForNominators = counterForNominators
        case let .failure(error):
            stateListener?.didReceiveError(error: error)
        }
    }

    func didReceiveStakingDuration(result: Result<StakingDuration, Error>) {
        switch result {
        case let .success(duration):
            stakingDuration = duration
            stateListener?.provideHints(viewModelState: self)
        case let .failure(error):
            stateListener?.didReceiveError(error: error)
        }
    }

    func didStartNomination() {
        stateListener?.didStartNomination()
    }

    func didCompleteNomination(txHash: String) {
        stateListener?.didCompleteNomination(txHash: txHash)
    }

    func didFailNomination(error: Error) {
        stateListener?.didFailNomination(error: error)
    }

    func didReceive(paymentInfo: RuntimeDispatchInfo) {
        if let feeValue = BigUInt(paymentInfo.fee),
           let fee = Decimal.fromSubstrateAmount(feeValue, precision: Int16(chainAsset.asset.precision)) {
            self.fee = fee
        } else {
            fee = nil
        }

        stateListener?.provideFee(viewModelState: self)
    }

    func didReceive(feeError: Error) {
        stateListener?.didReceiveError(error: feeError)
    }
}
