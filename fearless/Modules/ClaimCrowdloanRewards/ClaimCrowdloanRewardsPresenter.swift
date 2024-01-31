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
    private let wallet: MetaAccountModel
    private let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    private let viewModelFactory: ClaimCrowdloanRewardViewModelFactoryProtocol

    private var tokenLocks: [LockProtocol]?
    private var balanceLocks: [LockProtocol]?
    private var vestingSchedule: VestingSchedule?
    private var vesting: VestingVesting?
    private var priceData: PriceData?
    private var fee: RuntimeDispatchInfo?
    private var currentBlock: UInt32?
    private var accountInfo: AccountInfo?

    // MARK: - Constructors

    init(
        interactor: ClaimCrowdloanRewardsInteractorInput,
        router: ClaimCrowdloanRewardsRouterInput,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol?,
        chainAsset: ChainAsset,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        viewModelFactory: ClaimCrowdloanRewardViewModelFactoryProtocol,
        wallet: MetaAccountModel
    ) {
        self.interactor = interactor
        self.router = router
        self.logger = logger
        self.chainAsset = chainAsset
        self.balanceViewModelFactory = balanceViewModelFactory
        self.viewModelFactory = viewModelFactory
        self.wallet = wallet
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func getBalanceViewModelFactory(for chainAsset: ChainAsset) -> BalanceViewModelFactory {
        BalanceViewModelFactory(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            selectedMetaAccount: wallet
        )
    }

    private func provideVestingViewModel() {
        let locks = balanceLocks.or([]) + tokenLocks.or([])

        let viewModel = viewModelFactory.buildVestingViewModel(
            balanceLocks: locks,
            priceData: priceData
        )
        view?.didReceiveVestingViewModel(viewModel.value(for: selectedLocale))
    }

    private func provideBalanceViewModel() {
        let viewModel = viewModelFactory.buildBalanceViewModel(
            accountInfo: accountInfo,
            priceData: priceData
        )
        view?.didReceiveBalanceViewModel(viewModel.value(for: selectedLocale))
    }

    private func provideFeeViewModel() {
        guard let fee = fee else {
            view?.didReceiveFeeViewModel(nil)
            return
        }
        let feeChainAsset = getFeePaymentChainAsset()
        let balanceViewModelFactory = getBalanceViewModelFactory(for: feeChainAsset)
        let feeDecimal = BigUInt(string: fee.fee).map {
            Decimal.fromSubstrateAmount($0, precision: Int16(feeChainAsset.asset.precision)) ?? .zero
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

    private func getFeePaymentChainAsset() -> ChainAsset {
        if let utilityAsset = chainAsset.chain.utilityChainAssets().first {
            return utilityAsset
        }

        return chainAsset
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
        provideVestingViewModel()
    }

    func didReceiveTokenLocksError(_ error: Error) {
        logger?.error("Token locks error: \(error.localizedDescription)")
    }

    func didReceiveBalanceLocks(_ balanceLocks: [LockProtocol]?) {
        self.balanceLocks = balanceLocks
        provideVestingViewModel()
    }

    func didReceiveBalanceLocksError(_ error: Error) {
        logger?.error("Balance locks error: \(error.localizedDescription)")
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
        provideVestingViewModel()
        provideBalanceViewModel()
        provideFeeViewModel()
    }

    func didReceivePriceError(_ error: Error) {
        logger?.error("Vesting claim price error: \(error.localizedDescription)")
    }

    func didReceiveAccountInfo(accountInfo: AccountInfo?) {
        self.accountInfo = accountInfo
        provideBalanceViewModel()
    }
}

// MARK: - Localizable

extension ClaimCrowdloanRewardsPresenter: Localizable {
    func applyLocalization() {
        provideVestingViewModel()
    }
}

extension ClaimCrowdloanRewardsPresenter: ClaimCrowdloanRewardsModuleInput {}
