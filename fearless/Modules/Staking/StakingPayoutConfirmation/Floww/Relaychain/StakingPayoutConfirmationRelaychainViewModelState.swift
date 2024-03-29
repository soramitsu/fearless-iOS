import Foundation
import SSFModels

final class StakingPayoutConfirmationRelaychainViewModelState: StakingPayoutConfirmationViewModelState {
    var stateListener: StakingPayoutConfirmationModelStateListener?
    var fee: Decimal?
    var builderClosure: ExtrinsicBuilderClosure?
    private var balance: Decimal?
    private(set) var rewardAmount: Decimal = 0.0
    private(set) var account: ChainAccountResponse?
    private(set) var rewardDestination: RewardDestination<DisplayAddress>?
    private let callFactory: SubstrateCallFactoryProtocol
    private let logger: LoggerProtocol?
    private let chainAsset: ChainAsset
    private let wallet: MetaAccountModel
    private let dataValidatingFactory: StakingDataValidatingFactoryProtocol
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
}

extension StakingPayoutConfirmationRelaychainViewModelState: StakingPayoutConfirmationrelaychainStrategyOutput {
    func didStartPayout() {
        stateListener?.didStartPayout()
    }

    func didCompletePayout(txHashes: [String]) {
        stateListener?.didCompletePayout(txHashes: txHashes)
    }

    func didFailPayout(error: Error) {
        stateListener?.didFailPayout(error: error)
    }

    func didReceiveFee(result: Result<Decimal, Error>) {
        switch result {
        case let .success(fee):
            self.fee = fee
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

    func didReceiveRewardDestination(result: Result<RewardDestination<DisplayAddress>?, Error>) {
        switch result {
        case let .success(rewardDestination):
            self.rewardDestination = rewardDestination
            stateListener?.provideViewModel()
        case let .failure(error):
            logger?.error("Did receive reward destination error: \(error)")
        }
    }

    func didRecieve(account: ChainAccountResponse, rewardAmount: Decimal) {
        self.account = account
        self.rewardAmount = rewardAmount

        stateListener?.provideViewModel()
    }
}
