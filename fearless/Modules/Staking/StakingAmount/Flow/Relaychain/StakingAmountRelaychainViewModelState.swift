import Foundation
import BigInt
import CommonWallet
import SoraFoundation

final class StakingAmountRelaychainViewModelState: StakingAmountViewModelState {
    weak var stateListener: StakingAmountModelStateListener?
    let dataValidatingFactory: StakingDataValidatingFactoryProtocol
    let wallet: MetaAccountModel
    let chainAsset: ChainAsset

    private(set) var minimalBalance: Decimal?
    private(set) var minimumBond: Decimal?
    private(set) var counterForNominators: UInt32?
    private(set) var maxNominatorsCount: UInt32?
    var fee: Decimal?
    var amount: Decimal?

    var assetViewModel: AssetBalanceViewModelProtocol?
    var rewardDestinationViewModel: RewardDestinationViewModelProtocol?
    var feeViewModel: BalanceViewModelProtocol?
    var inputViewModel: AmountInputViewModelProtocol?

    var rewardDestination: RewardDestination<ChainAccountResponse> = .restake
    var payoutAccount: ChainAccountResponse?

    init(
        stateListener: StakingAmountModelStateListener?,
        dataValidatingFactory: StakingDataValidatingFactoryProtocol,
        wallet: MetaAccountModel,
        chainAsset: ChainAsset
    ) {
        self.stateListener = stateListener
        self.dataValidatingFactory = dataValidatingFactory
        self.wallet = wallet
        self.chainAsset = chainAsset
    }

    var feeExtrinsicBuilderClosure: ExtrinsicBuilderClosure {
        let closure: ExtrinsicBuilderClosure = { [weak self] builder in
            guard let strongSelf = self else {
                return builder
            }

            var modifiedBuilder = builder
            let callFactory = SubstrateCallFactory()

            if let amount = strongSelf.amount?.toSubstrateAmount(precision: Int16(strongSelf.chainAsset.asset.precision)),
               let controllerAddress = strongSelf.wallet.fetch(for: strongSelf.chainAsset.chain.accountRequest())?.toAddress() {
                let bondCall = try callFactory.bond(
                    amount: amount,
                    controller: controllerAddress,
                    rewardDestination: strongSelf.rewardDestination.accountAddress
                )

                modifiedBuilder = try modifiedBuilder.adding(call: bondCall)
            }

            if let controllerAddress = strongSelf.wallet.fetch(for: strongSelf.chainAsset.chain.accountRequest())?.toAddress() {
                let targets = Array(
                    repeating: SelectedValidatorInfo(address: controllerAddress),
                    count: SubstrateConstants.maxNominations
                )

                let nominateCall = try callFactory.nominate(targets: targets)
                modifiedBuilder = try modifiedBuilder
                    .adding(call: nominateCall)
            }

            return modifiedBuilder
        }

        return closure
    }

    var validators: [DataValidating] {
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

    private func notifyListeners() {
        stateListener?.modelStateDidChanged(viewModelState: self)
    }

    func selectPayoutDestination() {
        guard let payoutAccount = payoutAccount else {
            return
        }

        rewardDestination = .payout(account: payoutAccount)

        notifyListeners()
    }

    func selectRestakeDestination() {
        rewardDestination = .restake

        notifyListeners()
    }

    func setStateListener(_ stateListener: StakingAmountModelStateListener?) {
        self.stateListener = stateListener
    }

    func updateAmount(_ newValue: Decimal) {
        amount = newValue
    }
}

extension StakingAmountRelaychainViewModelState: StakingAmountRelaychainStrategyOutput {
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
}

extension StakingAmountRelaychainViewModelState: Localizable {
    func applyLocalization() {}
}
