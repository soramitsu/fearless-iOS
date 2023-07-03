import Foundation
import SSFModels
import BigInt

final class StakingPayoutConfirmationPoolViewModelState: StakingPayoutConfirmationViewModelState {
    var stateListener: StakingPayoutConfirmationModelStateListener?
    var fee: Decimal?
    private var balance: Decimal?
    private(set) var rewardAmount: Decimal = 0.0
    private(set) var account: ChainAccountResponse?
    private(set) var rewardDestination: RewardDestination<DisplayAddress>?

    private let logger: LoggerProtocol?
    private let chainAsset: ChainAsset
    private let wallet: MetaAccountModel
    private let dataValidatingFactory: StakingDataValidatingFactoryProtocol
    private let callFactory: SubstrateCallFactoryProtocol

    func setStateListener(_ stateListener: StakingPayoutConfirmationModelStateListener?) {
        self.stateListener = stateListener
    }

    func validators(using locale: Locale) -> [DataValidating] {
        [
            dataValidatingFactory.has(fee: fee, locale: locale) { [weak self] in
                self?.stateListener?.provideFee()
            },

            dataValidatingFactory.rewardIsHigherThanFee(
                reward: rewardAmount,
                fee: fee,
                locale: locale
            ),

            dataValidatingFactory.canPayFee(
                balance: balance,
                fee: fee,
                locale: locale
            )
        ]
    }

    init(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        logger: LoggerProtocol?,
        dataValidatingFactory: StakingDataValidatingFactoryProtocol,
        callFactory: SubstrateCallFactoryProtocol
    ) {
        self.chainAsset = chainAsset
        self.wallet = wallet
        self.logger = logger
        self.dataValidatingFactory = dataValidatingFactory
        self.callFactory = callFactory
    }

    var builderClosure: ExtrinsicBuilderClosure? {
        let call = callFactory.claimPoolRewards()
        let closure: ExtrinsicBuilderClosure = { builder in
            try builder.adding(call: call)
        }

        return closure
    }
}

extension StakingPayoutConfirmationPoolViewModelState: StakingPayoutConfirmationPoolStrategyOutput {
    func didStartPayout() {
        stateListener?.didStartPayout()
    }

    func didCompletePayout(result: SubmitExtrinsicResult) {
        stateListener?.didCompletePayout(result: result)
    }

    func didFailPayout(error: Error) {
        stateListener?.didFailPayout(error: error)
    }

    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>) {
        switch result {
        case let .success(dispatchInfo):
            if let feeValue = BigUInt(dispatchInfo.fee) {
                fee = Decimal.fromSubstrateAmount(feeValue, precision: Int16(chainAsset.asset.precision))
            } else {
                fee = nil
            }

            stateListener?.provideFee()

        case let .failure(error):

            logger?.error("Did receive fee error: \(error)")
        }
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
            logger?.error("Account Info subscription error: \(error)")
        }
    }

    func didRecieve(account: ChainAccountResponse, rewardAmount: Decimal) {
        self.account = account
        self.rewardAmount = rewardAmount

        stateListener?.provideViewModel()
    }
}
