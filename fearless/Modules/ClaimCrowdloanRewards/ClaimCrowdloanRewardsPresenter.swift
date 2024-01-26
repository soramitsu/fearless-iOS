import Foundation
import SoraFoundation
import SSFModels
import BigInt

final class ClaimCrowdloanRewardsPresenter {
    // MARK: Private properties

    private weak var view: ClaimCrowdloanRewardsViewInput?
    private let router: ClaimCrowdloanRewardsRouterInput
    private let interactor: ClaimCrowdloanRewardsInteractorInput
    private let logger: LoggerProtocol?
    private let chainAsset: ChainAsset
    private let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    private let viewModelFactory: ClaimCrowdloanRewardViewModelFactoryProtocol

    private var tokenLocks: [LockProtocol]?
    private var balanceLocks: [LockProtocol]?
    private var vestingSchedule: VestingSchedule?
    private var vesting: VestingVesting?
    private var priceData: PriceData?
    private var fee: RuntimeDispatchInfo?
    private var currentBlock: UInt32?

    // MARK: - Constructors

    init(
        interactor: ClaimCrowdloanRewardsInteractorInput,
        router: ClaimCrowdloanRewardsRouterInput,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol?,
        chainAsset: ChainAsset,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        viewModelFactory: ClaimCrowdloanRewardViewModelFactoryProtocol
    ) {
        self.interactor = interactor
        self.router = router
        self.logger = logger
        self.chainAsset = chainAsset
        self.balanceViewModelFactory = balanceViewModelFactory
        self.viewModelFactory = viewModelFactory
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func provideVestingViewModel(vesting: VestingVesting) {
        let locks = balanceLocks.or([]) + tokenLocks.or([])

        let viewModel = viewModelFactory.buildViewModel(
            vesting: vesting,
            balanceLocks: locks,
            locale: selectedLocale,
            priceData: priceData,
            currentBlock: currentBlock
        )
        view?.didReceiveViewModel(viewModel)
    }

    private func provideVestingScheduleViewModel(vestingSchedule: VestingSchedule) {
        let locks = balanceLocks.or([]) + tokenLocks.or([])

        let viewModel = viewModelFactory.buildViewModel(
            vestingSchedule: vestingSchedule,
            balanceLocks: locks,
            locale: selectedLocale,
            priceData: priceData,
            currentBlock: currentBlock
        )
        view?.didReceiveViewModel(viewModel)
    }

    private func provideViewModel() {
        if let vesting = vesting {
            provideVestingViewModel(vesting: vesting)
        }

        if let vestingSchedule = vestingSchedule {
            provideVestingScheduleViewModel(vestingSchedule: vestingSchedule)
        }
    }

    private func provideFeeViewModel() {
        guard let fee = fee else {
            view?.didReceiveFeeViewModel(nil)
            return
        }
        let feeDecimal = BigUInt(string: fee.fee).map {
            Decimal.fromSubstrateAmount($0, precision: Int16(chainAsset.asset.precision)) ?? .zero
        } ?? .zero

        let feeViewModel = balanceViewModelFactory.balanceFromPrice(feeDecimal, priceData: priceData, usageCase: .detailsCrypto)
        view?.didReceiveFeeViewModel(feeViewModel.value(for: selectedLocale))
    }

    private func provideStakeAmountViewModel() {
        let stakeAmountViewModel = viewModelFactory.createStakedAmountViewModel()
        view?.didReceiveStakeAmountViewModel(stakeAmountViewModel)
    }

    private func provideHintViewModel() {
        let viewModel = viewModelFactory.buildHintViewModel()
        view?.didReceiveHintViewModel(viewModel.value(for: selectedLocale))
    }
}

// MARK: - ClaimCrowdloanRewardsViewOutput

extension ClaimCrowdloanRewardsPresenter: ClaimCrowdloanRewardsViewOutput {
    func didLoad(view: ClaimCrowdloanRewardsViewInput) {
        self.view = view
        interactor.setup(with: self)

        interactor.estimateFee()

        provideStakeAmountViewModel()
        provideHintViewModel()
    }

    func backButtonClicked() {
        router.dismiss(view: view)
    }

    func confirmButtonClicked() {
        interactor.submit()
    }
}

// MARK: - ClaimCrowdloanRewardsInteractorOutput

extension ClaimCrowdloanRewardsPresenter: ClaimCrowdloanRewardsInteractorOutput {
    func didReceiveTokenLocks(_ balanceLocks: [LockProtocol]?) {
        tokenLocks = balanceLocks
        provideViewModel()
    }

    func didReceiveTokenLocksError(_ error: Error) {
        logger?.error("Token locks error: \(error.localizedDescription)")
    }

    func didReceiveBalanceLocks(_ balanceLocks: [LockProtocol]?) {
        self.balanceLocks = balanceLocks
        provideViewModel()
    }

    func didReceiveBalanceLocksError(_ error: Error) {
        logger?.error("Balance locks error: \(error.localizedDescription)")
    }

    func didReceiveVestingSchedule(_ vestingSchedule: VestingSchedule?) {
        self.vestingSchedule = vestingSchedule
        provideViewModel()
    }

    func didReceiveVestingScheduleError(_ error: Error) {
        logger?.error("Vesting schedule error: \(error.localizedDescription)")
    }

    func didReceiveFee(_ fee: RuntimeDispatchInfo) {
        self.fee = fee
        provideFeeViewModel()
    }

    func didReceiveFeeError(_ error: Error) {
        logger?.error("Vesting claim fee error: \(error.localizedDescription)")
    }

    func didReceiveTxHash(_ txHash: String) {
        guard let view else { return }
        router.presentDone(
            chainAsset: chainAsset,
            title: R.string.localizable.transactionSuccessful(preferredLanguages: selectedLocale.rLanguages),
            description: nil,
            extrinsicHash: txHash,
            from: view,
            closure: nil
        )
    }

    func didReceiveTxError(_ error: Error) {
        router.present(error: error, from: view, locale: selectedLocale)
    }

    func didReceivePrice(_ price: PriceData?) {
        priceData = price
        provideViewModel()
    }

    func didReceivePriceError(_ error: Error) {
        logger?.error("Vesting claim price error: \(error.localizedDescription)")
    }

    func didReceiveCurrenBlock(_ currentBlock: UInt32?) {
        self.currentBlock = currentBlock
        provideViewModel()
    }

    func didReceiveCurrentBlockError(_ error: Error) {
        logger?.error("Vesting claim current block error: \(error.localizedDescription)")
    }

    func didReceiveVestingVesting(_ vesting: VestingVesting?) {
        self.vesting = vesting
        provideViewModel()
    }

    func didReceiveVestingVestingError(_ error: Error) {
        logger?.error("Vesting vesting error: \(error.localizedDescription)")
    }
}

// MARK: - Localizable

extension ClaimCrowdloanRewardsPresenter: Localizable {
    func applyLocalization() {}
}

extension ClaimCrowdloanRewardsPresenter: ClaimCrowdloanRewardsModuleInput {}
