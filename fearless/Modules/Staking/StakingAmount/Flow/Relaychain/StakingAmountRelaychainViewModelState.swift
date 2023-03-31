import Foundation
import BigInt
import CommonWallet
import SoraFoundation

final class StakingAmountRelaychainViewModelState: StakingAmountViewModelState {
    weak var stateListener: StakingAmountModelStateListener?
    let dataValidatingFactory: StakingDataValidatingFactoryProtocol
    let wallet: MetaAccountModel
    let chainAsset: ChainAsset
    private let callFactory: SubstrateCallFactoryProtocol

    private var networkStakingInfo: NetworkStakingInfo?
    private var minStake: Decimal?
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
    private(set) var rewardAssetPrice: PriceData?
    var payoutAccount: ChainAccountResponse?
    var fee: Decimal?
    var amount: Decimal? { inputResult?.absoluteValue(from: balanceMinusFee) }
    private var balance: Decimal?
    private var balanceMinusFee: Decimal { (balance ?? 0) - (fee ?? 0) }
    private var inputResult: AmountInputResult?

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
        callFactory: SubstrateCallFactoryProtocol

    ) {
        self.dataValidatingFactory = dataValidatingFactory
        self.wallet = wallet
        self.chainAsset = chainAsset
        self.callFactory = callFactory
        inputResult = .absolute(amount ?? 0)

        payoutAccount = wallet.fetch(for: chainAsset.chain.accountRequest())
    }

    func validators(using _: Locale) -> [DataValidating] {
        [dataValidatingFactory.canNominate(
            amount: amount,
            minimalBalance: minimalBalance,
            minNominatorBond: minimumBond,
            locale: selectedLocale
        ),
        dataValidatingFactory.maxNominatorsCountNotApplied(
            counterForNominators: counterForNominators,
            maxNominatorsCount: maxNominatorsCount,
            hasExistingNomination: false,
            locale: selectedLocale
        )]
    }

    func selectPayoutDestination() {
        guard let payoutAccount = payoutAccount else {
            return
        }

        rewardDestination = .payout(account: payoutAccount)

        stateListener?.provideSelectRewardDestinationViewModel(viewModelState: self)
    }

    func selectRestakeDestination() {
        rewardDestination = .restake

        stateListener?.provideSelectRewardDestinationViewModel(viewModelState: self)
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

        stateListener?.provideSelectRewardDestinationViewModel(viewModelState: self)
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
        self.minimumBond = minimumBond.map { Decimal.fromSubstrateAmount($0, precision: Int16(chainAsset.asset.precision)) } ?? nil

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
        if let feeValue = BigUInt(paymentInfo.fee),
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
    }

    func didReceive(networkStakingInfoError: Error) {
        Logger.shared.error("StakingAmountRelaychainViewModelState.didReceiveNetworkStakingInfoError: \(networkStakingInfoError)")
    }

    func didReceive(rewardAssetPrice: PriceData?) {
        self.rewardAssetPrice = rewardAssetPrice

        stateListener?.provideSelectRewardDestinationViewModel(viewModelState: self)
    }
}

extension StakingAmountRelaychainViewModelState: Localizable {
    func applyLocalization() {
        notifyListeners()
    }
}
