import Foundation
import BigInt

final class StakingRebondConfirmationPresenter {
    weak var view: StakingRebondConfirmationViewProtocol?
    let wireframe: StakingRebondConfirmationWireframeProtocol
    let interactor: StakingRebondConfirmationInteractorInputProtocol

    let variant: SelectedRebondVariant
    let confirmViewModelFactory: StakingRebondConfirmationViewModelFactoryProtocol
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let dataValidatingFactory: StakingDataValidatingFactoryProtocol
    let chain: Chain
    let logger: LoggerProtocol?

    var inputAmount: Decimal? {
        switch variant {
        case .all:
            if
                let ledger = stakingLedger,
                let era = activeEra {
                let value = ledger.unbounding(inEra: era)
                return Decimal.fromSubstrateAmount(value, precision: chain.addressType.precision)
            } else {
                return nil
            }
        case .last:
            if
                let ledger = stakingLedger,
                let era = activeEra,
                let chunk = ledger.unboundings(inEra: era).last {
                return Decimal.fromSubstrateAmount(chunk.value, precision: chain.addressType.precision)
            } else {
                return nil
            }
        case let .custom(amount):
            return amount
        }
    }

    var unbonding: Decimal? {
        if let activeEra = activeEra, let value = stakingLedger?.unbounding(inEra: activeEra) {
            return Decimal.fromSubstrateAmount(value, precision: chain.addressType.precision)
        } else {
            return nil
        }
    }

    private var stakingLedger: DyStakingLedger?
    private var activeEra: UInt32?
    private var balance: Decimal?
    private var priceData: PriceData?
    private var fee: Decimal?
    private var electionStatus: ElectionStatus?
    private var controller: AccountItem?
    private var stashItem: StashItem?

    init(
        variant: SelectedRebondVariant,
        interactor: StakingRebondConfirmationInteractorInputProtocol,
        wireframe: StakingRebondConfirmationWireframeProtocol,
        confirmViewModelFactory: StakingRebondConfirmationViewModelFactoryProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        dataValidatingFactory: StakingDataValidatingFactoryProtocol,
        chain: Chain,
        logger: LoggerProtocol? = nil
    ) {
        self.variant = variant
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
            let inputAmount = inputAmount,
            let unbonding = unbonding else {
            return
        }

        let viewModel = balanceViewModelFactory.createAssetBalanceViewModel(
            inputAmount,
            balance: unbonding,
            priceData: priceData
        )

        view?.didReceiveAsset(viewModel: viewModel)
    }

    private func provideConfirmationViewModel() {
        guard let controller = controller,
              let inputAmount = inputAmount else {
            return
        }

        do {
            let viewModel = try confirmViewModelFactory.createViewModel(
                controllerItem: controller,
                amount: inputAmount
            )

            view?.didReceiveConfirmation(viewModel: viewModel)
        } catch {
            logger?.error("Did receive view model factory error: \(error)")
        }
    }

    func refreshFeeIfNeeded() {
        guard fee == nil, let amount = inputAmount else {
            return
        }

        interactor.estimateFee(for: amount)
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
            dataValidatingFactory.canRebond(amount: inputAmount, unbonding: unbonding, locale: locale),

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
