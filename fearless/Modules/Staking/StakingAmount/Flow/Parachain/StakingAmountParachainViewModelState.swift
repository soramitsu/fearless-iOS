import Foundation
import BigInt
import SSFModels

class StakingAmountParachainViewModelState: StakingAmountViewModelState {
    var fee: Decimal?

    var stateListener: StakingAmountModelStateListener?
    let dataValidatingFactory: StakingDataValidatingFactoryProtocol
    private let callFactory: SubstrateCallFactoryProtocol

    let wallet: MetaAccountModel
    let chainAsset: ChainAsset
    private var networkStakingInfo: NetworkStakingInfo?
    private var minStake: Decimal?
    private(set) var minimalBalance: Decimal?
    var amount: Decimal? { inputResult?.absoluteValue(from: balanceMinusFeeAndED) }
    private var balance: Decimal?
    private var inputResult: AmountInputResult?
    private lazy var balanceMinusFeeAndED: Decimal = {
        (balance ?? 0) - (fee ?? 0) - (minimalBalance ?? 0)
    }()

    init(
        dataValidatingFactory: StakingDataValidatingFactoryProtocol,
        wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        amount: Decimal?,
        callFactory: SubstrateCallFactoryProtocol
    ) {
        self.dataValidatingFactory = dataValidatingFactory
        self.wallet = wallet
        self.chainAsset = chainAsset
        self.callFactory = callFactory

        if let amount = amount {
            inputResult = .absolute(amount)
        }
    }

    var payoutAccount: ChainAccountResponse? { nil }

    var continueAvailable: Bool {
        minimalBalance != nil && networkStakingInfo != nil && minStake != nil
    }

    var bonding: InitiatedBonding? {
        guard let amount = amount, let account = wallet.fetch(for: chainAsset.chain.accountRequest()) else {
            return nil
        }

        return InitiatedBonding(amount: amount, rewardDestination: .payout(account: account))
    }

    var learnMoreUrl: URL? {
        URL(string: "https://docs.moonbeam.network/learn/features/staking/")
    }

    var feeExtrinsicBuilderClosure: ExtrinsicBuilderClosure {
        let closure: ExtrinsicBuilderClosure = { [unowned self] builder in
            guard let accountId = Data.random(of: 20),
                  let amount = StakingConstants.maxAmount.toSubstrateAmount(
                      precision: Int16(self.chainAsset.asset.precision)
                  ) else {
                return builder
            }

            let call = callFactory.delegate(
                candidate: accountId,
                amount: amount,
                candidateDelegationCount: UInt32.max,
                delegationCount: UInt32.max
            )

            return try builder.adding(call: call)
        }

        return closure
    }

    func validators(using locale: Locale) -> [DataValidating] {
        let minimumStake = Decimal.fromSubstrateAmount(networkStakingInfo?.baseInfo.minStakeAmongActiveNominators ?? BigUInt.zero, precision: Int16(chainAsset.asset.precision)) ?? 0

        let amountSubstrate = amount?.toSubstrateAmount(precision: Int16(chainAsset.asset.precision))
        let balanceSubstrate = balance?.toSubstrateAmount(precision: Int16(chainAsset.asset.precision))
        let edSubstrate = minimalBalance?.toSubstrateAmount(precision: Int16(chainAsset.asset.precision))

        return [
            dataValidatingFactory.canNominate(
                amount: amount,
                minimalBalance: minimalBalance,
                minNominatorBond: minimumStake,
                locale: locale
            ),
            dataValidatingFactory.bondAtLeastMinStaking(
                asset: chainAsset.asset,
                amount: amount,
                minNominatorBond: minStake,
                locale: locale
            ),
            dataValidatingFactory.exsitentialDepositIsNotViolated(
                spendingAmount: amountSubstrate,
                totalAmount: balanceSubstrate,
                minimumBalance: edSubstrate,
                locale: locale,
                chainAsset: chainAsset,
                canProceedIfViolated: false
            )
        ]
    }

    private func notifyListeners() {
        stateListener?.modelStateDidChanged(viewModelState: self)
    }

    func setStateListener(_ stateListener: StakingAmountModelStateListener?) {
        self.stateListener = stateListener
    }

    func updateAmount(_ newValue: Decimal) {
        inputResult = .absolute(newValue)
    }

    func selectAmountPercentage(_ percentage: Float) {
        inputResult = .rate(Decimal(Double(percentage)))
    }

    func updateBalance(_ balance: Decimal?) {
        self.balance = balance
    }
}

extension StakingAmountParachainViewModelState: StakingAmountParachainStrategyOutput {
    func didReceive(minimalBalance: BigUInt?) {
        if let minimalBalance = minimalBalance,
           let amount = Decimal.fromSubstrateAmount(minimalBalance, precision: Int16(chainAsset.asset.precision)) {
            self.minimalBalance = amount

            notifyListeners()
        }
    }

    func didReceive(networkStakingInfo: NetworkStakingInfo) {
        self.networkStakingInfo = networkStakingInfo

        let minStakeSubstrateAmount = networkStakingInfo.calculateMinimumStake(given: networkStakingInfo.baseInfo.minStakeAmongActiveNominators)
        minStake = Decimal.fromSubstrateAmount(minStakeSubstrateAmount, precision: Int16(chainAsset.asset.precision))

        notifyListeners()
    }

    func didSetup() {
        stateListener?.provideYourRewardDestinationViewModel(viewModelState: self)
    }

    func didReceive(networkStakingInfoError _: Error) {}

    func didReceive(error _: Error) {}

    func didReceive(paymentInfo: RuntimeDispatchInfo) {
        if let feeValue = BigUInt(string: paymentInfo.fee),
           let fee = Decimal.fromSubstrateAmount(feeValue, precision: Int16(chainAsset.asset.precision)) {
            self.fee = fee
        } else {
            fee = nil
        }

        notifyListeners()
    }
}
