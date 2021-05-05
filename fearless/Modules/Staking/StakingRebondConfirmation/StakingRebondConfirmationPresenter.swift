import Foundation
import BigInt

final class StakingRebondConfirmationPresenter {
    weak var view: StakingRebondConfirmationViewProtocol?
    let wireframe: StakingRebondConfirmationWireframeProtocol
    let interactor: StakingRebondConfirmationInteractorInputProtocol

    let confirmViewModelFactory: StakingRebondConfirmationViewModelFactoryProtocol
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let dataValidatingFactory: StakingDataValidatingFactoryProtocol
    let chain: Chain
    let logger: LoggerProtocol?
    let inputAmount: Decimal

    private var stakingLedger: DyStakingLedger?
    private var activeEra: UInt32?
    private var balance: Decimal?
    private var priceData: PriceData?
    private var fee: Decimal?
    private var electionStatus: ElectionStatus?
    private var controller: AccountItem?
    private var stashItem: StashItem?

    init(
        inputAmount: Decimal,
        interactor: StakingRebondConfirmationInteractorInputProtocol,
        wireframe: StakingRebondConfirmationWireframeProtocol,
        confirmViewModelFactory: StakingRebondConfirmationViewModelFactoryProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        dataValidatingFactory: StakingDataValidatingFactoryProtocol,
        chain: Chain,
        logger: LoggerProtocol? = nil
    ) {
        self.inputAmount = inputAmount
        self.interactor = interactor
        self.wireframe = wireframe
        self.confirmViewModelFactory = confirmViewModelFactory
        self.balanceViewModelFactory = balanceViewModelFactory
        self.dataValidatingFactory = dataValidatingFactory
        self.chain = chain
        self.logger = logger
    }

    private func provideFeeViewModel() {
        if let fee = fee {
            let feeViewModel = balanceViewModelFactory.balanceFromPrice(fee, priceData: priceData)
            view?.didReceiveFee(viewModel: feeViewModel)
        } else {
            view?.didReceiveFee(viewModel: nil)
        }
    }

    private func provideAssetViewModel() {
        guard
            let era = activeEra,
            let redeemable = stakingLedger?.redeemable(inEra: era),
            let redeemableDecimal = Decimal.fromSubstrateAmount(
                redeemable,
                precision: chain.addressType.precision
            ) else {
            return
        }

        let viewModel = balanceViewModelFactory.createAssetBalanceViewModel(
            redeemableDecimal,
            balance: redeemableDecimal,
            priceData: priceData
        )

        view?.didReceiveAsset(viewModel: viewModel)
    }

    private func provideConfirmationViewModel() {
        guard let controller = controller,
              let era = activeEra,
              let redeemable = stakingLedger?.redeemable(inEra: era),
              let redeemableDecimal = Decimal.fromSubstrateAmount(
                  redeemable,
                  precision: chain.addressType.precision
              ) else {
            return
        }

        do {
            let viewModel = try confirmViewModelFactory.createViewModel(
                controllerItem: controller,
                amount: redeemableDecimal
            )

            view?.didReceiveConfirmation(viewModel: viewModel)
        } catch {
            logger?.error("Did receive view model factory error: \(error)")
        }
    }

    func refreshFeeIfNeeded() {
        guard fee == nil else {
            return
        }

        interactor.estimateFee(for: inputAmount)
    }
}

extension StakingRebondConfirmationPresenter: StakingRebondConfirmationPresenterProtocol {
    func setup() {
        provideConfirmationViewModel()
        provideAssetViewModel()
        provideFeeViewModel()

        interactor.setup()
    }

    func confirm() {
        let locale = view?.localizationManager?.selectedLocale ?? Locale.current
        DataValidationRunner(validators: [
            dataValidatingFactory.hasRedeemable(
                stakingLedger: stakingLedger,
                in: activeEra,
                locale: locale
            ),

            dataValidatingFactory.has(fee: fee, locale: locale, onError: { [weak self] in
                self?.refreshFeeIfNeeded()
            }),

            dataValidatingFactory.canPayFee(balance: balance, fee: fee, locale: locale),

            dataValidatingFactory.has(
                controller: controller,
                for: stashItem?.controller ?? "",
                locale: locale
            ),

            dataValidatingFactory.electionClosed(electionStatus, locale: locale)
        ]).runValidation { [weak self] in
            guard let strongSelf = self, let inputAmount = self?.inputAmount else {
                return
            }

            strongSelf.view?.didStartLoading()

            strongSelf.interactor.submit(for: inputAmount)
        }
    }

    func selectAccount() {
        guard let view = view, let address = stashItem?.controller else { return }

        let locale = view.localizationManager?.selectedLocale ?? Locale.current
        wireframe.presentAccountOptions(from: view, address: address, chain: chain, locale: locale)
    }
}

extension StakingRebondConfirmationPresenter: StakingRebondConfirmationInteractorOutputProtocol {
    func didReceiveElectionStatus(result: Result<ElectionStatus?, Error>) {
        switch result {
        case let .success(electionStatus):
            self.electionStatus = electionStatus
        case let .failure(error):
            logger?.error("Election status error: \(error)")
        }
    }

    func didReceiveAccountInfo(result: Result<DyAccountInfo?, Error>) {
        switch result {
        case let .success(accountInfo):
            if let accountInfo = accountInfo {
                balance = Decimal.fromSubstrateAmount(
                    accountInfo.data.available,
                    precision: chain.addressType.precision
                )
            } else {
                balance = nil
            }
        case let .failure(error):
            logger?.error("Account Info subscription error: \(error)")
        }
    }

    func didReceiveStakingLedger(result: Result<DyStakingLedger?, Error>) {
        switch result {
        case let .success(stakingLedger):
            self.stakingLedger = stakingLedger

            provideConfirmationViewModel()
            provideAssetViewModel()
            refreshFeeIfNeeded()
        case let .failure(error):
            logger?.error("Staking ledger subscription error: \(error)")
        }
    }

    func didReceivePriceData(result: Result<PriceData?, Error>) {
        switch result {
        case let .success(priceData):
            self.priceData = priceData

            provideAssetViewModel()
            provideFeeViewModel()
            provideConfirmationViewModel()
        case let .failure(error):
            logger?.error("Price data subscription error: \(error)")
        }
    }

    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>) {
        switch result {
        case let .success(dispatchInfo):
            if let fee = BigUInt(dispatchInfo.fee) {
                self.fee = Decimal.fromSubstrateAmount(fee, precision: chain.addressType.precision)
            }

            provideFeeViewModel()
        case let .failure(error):
            logger?.error("Did receive fee error: \(error)")
        }
    }

    func didReceiveController(result: Result<AccountItem?, Error>) {
        switch result {
        case let .success(accountItem):
            if let accountItem = accountItem {
                controller = accountItem
            }

            provideConfirmationViewModel()
            refreshFeeIfNeeded()
        case let .failure(error):
            logger?.error("Did receive controller account error: \(error)")
        }
    }

    func didReceiveStashItem(result: Result<StashItem?, Error>) {
        switch result {
        case let .success(stashItem):
            self.stashItem = stashItem
        case let .failure(error):
            logger?.error("Did receive stash item error: \(error)")
        }
    }

    func didReceiveActiveEra(result: Result<ActiveEraInfo?, Error>) {
        switch result {
        case let .success(eraInfo):
            activeEra = eraInfo?.index

            provideAssetViewModel()
            provideConfirmationViewModel()
        case let .failure(error):
            logger?.error("Did receive active era error: \(error)")
        }
    }

    func didSubmitRebonding(result: Result<String, Error>) {
        view?.didStopLoading()

        guard let view = view else {
            return
        }

        switch result {
        case .success:
            wireframe.complete(from: view)
        case .failure:
            wireframe.presentExtrinsicFailed(from: view, locale: view.localizationManager?.selectedLocale)
        }
    }
}
