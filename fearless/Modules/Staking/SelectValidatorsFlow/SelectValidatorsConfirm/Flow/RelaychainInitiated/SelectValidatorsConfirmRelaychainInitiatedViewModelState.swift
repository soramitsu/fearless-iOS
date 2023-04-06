import Foundation
import RobinHood
import BigInt

final class SelectValidatorsConfirmRelaychainInitiatedViewModelState: SelectValidatorsConfirmViewModelState {
    var balance: Decimal?
    var amount: Decimal? { initiatedBonding.amount }
    var stateListener: SelectValidatorsConfirmModelStateListener?
    let targets: [SelectedValidatorInfo]
    let maxTargets: Int
    let initiatedBonding: InitiatedBonding
    let chainAsset: ChainAsset
    let wallet: MetaAccountModel
    let dataValidatingFactory: StakingDataValidatingFactoryProtocol
    private let callFactory: SubstrateCallFactoryProtocol

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
        targets: [SelectedValidatorInfo],
        maxTargets: Int,
        initiatedBonding: InitiatedBonding,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        dataValidatingFactory: StakingDataValidatingFactoryProtocol,
        callFactory: SubstrateCallFactoryProtocol
    ) {
        self.targets = targets
        self.maxTargets = maxTargets
        self.initiatedBonding = initiatedBonding
        self.chainAsset = chainAsset
        self.wallet = wallet
        self.dataValidatingFactory = dataValidatingFactory
        self.callFactory = callFactory
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
            ),
            dataValidatingFactory.canPayFeeAndAmount(
                balance: balance,
                fee: fee,
                spendingAmount: amount,
                locale: locale
            )
        ]
    }

    func createExtrinsicBuilderClosure() -> ExtrinsicBuilderClosure? {
        guard let amount = initiatedBonding.amount
            .toSubstrateAmount(precision: Int16(chainAsset.asset.precision)),
            let address = wallet.fetch(for: chainAsset.chain.accountRequest())?.toAddress()
        else {
            return nil
        }

        let rewardDestination = initiatedBonding.rewardDestination.accountAddress
        let targets = targets

        let closure: ExtrinsicBuilderClosure = { [weak self] builder in
            guard let strongSelf = self else {
                return builder
            }

            let bondCall = try strongSelf.callFactory.bond(
                amount: amount,
                controller: address,
                rewardDestination: rewardDestination
            )

            let nominateCall = try strongSelf.callFactory.nominate(targets: targets)

            return try builder
                .adding(call: bondCall)
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

extension SelectValidatorsConfirmRelaychainInitiatedViewModelState: SelectValidatorsConfirmRelaychainInitiatedStrategyOutput {
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

    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>) {
        switch result {
        case let .success(accountInfo):
            if let availableValue = accountInfo?.data.stakingAvailable {
                balance = Decimal.fromSubstrateAmount(
                    availableValue,
                    precision: Int16(chainAsset.asset.precision)
                )
            } else {
                balance = 0.0
            }
        case let .failure(error):
            stateListener?.didReceiveError(error: error)
        }
    }
}
