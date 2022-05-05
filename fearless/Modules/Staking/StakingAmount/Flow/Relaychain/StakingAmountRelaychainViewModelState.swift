import Foundation
import BigInt
import CommonWallet
import SoraFoundation

protocol StakingAmountModelStateListener: AnyObject {
    func modelStateDidChanged(viewModelState: StakingAmountViewModelState)
}

protocol StakingAmountViewModelState: StakingAmountUserInputHandler {
    var stateListener: StakingAmountModelStateListener? { get set }
    var feeExtrinsicBuilderClosure: ExtrinsicBuilderClosure { get }
    var validators: [DataValidating] { get }

    var amount: Decimal? { get set }
}

final class StakingAmountRelaychainViewModelState: StakingAmountViewModelState {
    weak var stateListener: StakingAmountModelStateListener?
    let dataValidatingFactory: StakingDataValidatingFactoryProtocol
    let wallet: MetaAccountModel
    let chainAsset: ChainAsset

    private var minimalBalance: Decimal?
    private var minimumBond: Decimal?
    private var counterForNominators: UInt32?
    private var maxNominatorsCount: UInt32?

    var assetViewModel: AssetBalanceViewModelProtocol?
    var rewardDestinationViewModel: RewardDestinationViewModelProtocol?
    var feeViewModel: BalanceViewModelProtocol?
    var inputViewModel: AmountInputViewModelProtocol?

    var rewardDestination: RewardDestination<ChainAccountResponse> = .restake
    var payoutAccount: ChainAccountResponse?
    var amount: Decimal?

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
}

extension StakingAmountRelaychainViewModelState: Localizable {
    func applyLocalization() {}
}
