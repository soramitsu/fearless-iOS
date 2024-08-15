import Foundation
import BigInt

import SoraFoundation
import SSFModels

final class StakingAmountRelaychainViewModelState: StakingAmountViewModelState {
    weak var stateListener: StakingAmountModelStateListener?
    let dataValidatingFactory: StakingDataValidatingFactoryProtocol
    let wallet: MetaAccountModel
    let chainAsset: ChainAsset
    let rewardChainAsset: ChainAsset?
    private let callFactory: SubstrateCallFactoryProtocol

    private var networkStakingInfo: NetworkStakingInfo?
    private(set) var minStake: Decimal?
    private(set) var minimalBalance: Decimal?
    private(set) var minimumBond: Decimal?
    private(set) var counterForNominators: UInt32?
    private(set) var maxNominatorsCount: UInt32?
    private(set) var assetViewModel: AssetBalanceViewModelProtocol?
    private(set) var rewardDestinationViewModel: RewardDestinationViewModelProtocol?
    private(set) var feeViewModel: BalanceViewModelProtocol?
    private(set) var inputViewModel: IAmountInputViewModel?
    private(set) var rewardDestination: RewardDestination<ChainAccountResponse> = .restake
    private(set) var maxNominations: Int?
    var payoutAccount: ChainAccountResponse?
    var fee: Decimal?
    var amount: Decimal? {
        let balanceMinusFeeAndED = (balance ?? 0) - (fee ?? 0) - (minimalBalance ?? 0)
        return inputResult?.absoluteValue(from: balanceMinusFeeAndED)
    }

    private var balance: Decimal?
    private var inputResult: AmountInputResult?

    var continueAvailable: Bool {
        minStake != nil && minimumBond != nil && fee != nil && balance != nil && counterForNominators != nil
    }

    var bonding: InitiatedBonding? {
        guard let amount = amount else {
            return nil
        }

        return InitiatedBonding(amount: amount, rewardDestination: rewardDestination)
    }

    var learnMoreUrl: URL? {
        ApplicationConfig.shared.learnPayoutURL
    }

    var feeExtrinsicBuilderClosure: ExtrinsicBuilderClosure {
        buildExtrinsicBuilderClosure()
    }

    init(
        dataValidatingFactory: StakingDataValidatingFactoryProtocol,
        wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        amount: Decimal?,
        callFactory: SubstrateCallFactoryProtocol,
        rewardChainAsset: ChainAsset?
    ) {
        self.dataValidatingFactory = dataValidatingFactory
        self.wallet = wallet
        self.chainAsset = chainAsset
        self.callFactory = callFactory
        self.rewardChainAsset = rewardChainAsset

        if let amount = amount {
            inputResult = .absolute(amount)
        }

        payoutAccount = wallet.fetch(for: chainAsset.chain.accountRequest())

        if let payoutAccount = payoutAccount {
            rewardDestination = chainAsset.chain.isSora ? .payout(account: payoutAccount) : .restake
        }
    }

    func validators(using _: Locale) -> [DataValidating] {
        func calculateMinimumBond() -> Decimal? {
            guard let minStake = minStake, let minimumBond = minimumBond else {
                return nil
            }

            return max(minimumBond, minStake)
        }

        let amountSubstrate = amount?.toSubstrateAmount(precision: Int16(chainAsset.asset.precision))
        let balanceSubstrate = balance?.toSubstrateAmount(precision: Int16(chainAsset.asset.precision))
        let edSubstrate = minimalBalance?.toSubstrateAmount(precision: Int16(chainAsset.asset.precision))

        let minNominatorBond = calculateMinimumBond()
        return [
            dataValidatingFactory.canNominate(
                amount: amount,
                minimalBalance: minimalBalance,
                minNominatorBond: minNominatorBond,
                locale: selectedLocale
            ),
            dataValidatingFactory.maxNominatorsCountNotApplied(
                counterForNominators: counterForNominators,
                maxNominatorsCount: maxNominatorsCount,
                hasExistingNomination: false,
                locale: selectedLocale
            ),
            dataValidatingFactory.exsitentialDepositIsNotViolated(
                spendingAmount: amountSubstrate,
                totalAmount: balanceSubstrate,
                minimumBalance: edSubstrate,
                locale: selectedLocale,
                chainAsset: chainAsset,
                canProceedIfViolated: false
            )
        ]
    }

    func selectPayoutDestination() {
        guard let payoutAccount = payoutAccount else {
            return
        }

        rewardDestination = .payout(account: payoutAccount)

        stateListener?.modelStateDidChanged(viewModelState: self)
    }

    func selectRestakeDestination() {
        rewardDestination = .restake

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

    func selectPayoutAccount(payoutAccount: ChainAccountResponse?) {
        guard let payoutAccount = payoutAccount else {
            return
        }

        self.payoutAccount = payoutAccount

        rewardDestination = .payout(account: payoutAccount)

        stateListener?.modelStateDidChanged(viewModelState: self)
    }

    func updateBalance(_ balance: Decimal?) {
        self.balance = balance
    }

    private func notifyListeners() {
        stateListener?.modelStateDidChanged(viewModelState: self)
    }

    private func buildExtrinsicBuilderClosure() -> ExtrinsicBuilderClosure {
        let closure: ExtrinsicBuilderClosure = { [weak self] builder in
            guard let strongSelf = self else {
                return builder
            }

            var modifiedBuilder = builder
            let accountRequest = strongSelf.chainAsset.chain.accountRequest()

            if
                let amount = strongSelf.amount?.toSubstrateAmount(
                    precision: Int16(strongSelf.chainAsset.asset.precision)
                ),
                let controllerAddress = strongSelf.wallet.fetch(for: accountRequest)?.toAddress() {
                let bondCall = try strongSelf.callFactory.bond(
                    amount: amount,
                    controller: controllerAddress,
                    rewardDestination: strongSelf.rewardDestination.accountAddress,
                    chainAsset: strongSelf.chainAsset
                )

                modifiedBuilder = try modifiedBuilder.adding(call: bondCall)
            }

            if
                let controllerAddress = strongSelf.wallet.fetch(for: accountRequest)?.toAddress(),
                let maxNominators = strongSelf.maxNominations {
                let targets = Array(
                    repeating: SelectedValidatorInfo(address: controllerAddress),
                    count: maxNominators
                )

                let nominateCall = try strongSelf.callFactory.nominate(
                    targets: targets,
                    chainAsset: strongSelf.chainAsset
                )
                modifiedBuilder = try modifiedBuilder
                    .adding(call: nominateCall)
            }

            return modifiedBuilder
        }

        return closure
    }
}

extension StakingAmountRelaychainViewModelState: StakingAmountRelaychainStrategyOutput {
    func didReceive(maxNominations: Int) {
        self.maxNominations = maxNominations

        notifyListeners()
    }

    func didReceive(error _: Error) {}

    func didReceive(minimalBalance: BigUInt?) {
        if let minimalBalance = minimalBalance,
           let amount = Decimal.fromSubstrateAmount(minimalBalance, precision: Int16(chainAsset.asset.precision)) {
            self.minimalBalance = amount

            notifyListeners()
        }
    }

    func didReceive(minimumBond: BigUInt?) {
        self.minimumBond = minimumBond.map { Decimal.fromSubstrateAmount($0, precision: Int16(chainAsset.asset.precision)) } ?? Decimal.zero

        notifyListeners()
    }

    func didReceive(counterForNominators: UInt32?) {
        self.counterForNominators = counterForNominators

        notifyListeners()
    }

    func didReceive(maxNominatorsCount: UInt32?) {
        self.maxNominatorsCount = maxNominatorsCount

        notifyListeners()
    }

    func didReceive(paymentInfo: RuntimeDispatchInfo) {
        if let feeValue = BigUInt(string: paymentInfo.fee),
           let fee = Decimal.fromSubstrateAmount(feeValue, precision: Int16(chainAsset.asset.precision)) {
            self.fee = fee
        } else {
            fee = nil
        }

        notifyListeners()
    }

    func didReceive(networkStakingInfo: NetworkStakingInfo) {
        self.networkStakingInfo = networkStakingInfo

        let minStakeSubstrateAmount = networkStakingInfo.calculateMinimumStake(given: minimumBond?.toSubstrateAmount(precision: Int16(chainAsset.asset.precision)))
        minStake = Decimal.fromSubstrateAmount(minStakeSubstrateAmount, precision: Int16(chainAsset.asset.precision))

        notifyListeners()
    }

    func didReceive(networkStakingInfoError: Error) {
        Logger.shared.error("StakingAmountRelaychainViewModelState.didReceiveNetworkStakingInfoError: \(networkStakingInfoError)")
    }
}

extension StakingAmountRelaychainViewModelState: Localizable {
    func applyLocalization() {
        notifyListeners()
    }
}
