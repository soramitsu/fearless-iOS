import SoraFoundation

final class StakingBalancePresenter {
    let interactor: StakingBalanceInteractorInputProtocol
    let wireframe: StakingBalanceWireframeProtocol
    let viewModelFactory: StakingBalanceViewModelFactoryProtocol
    weak var view: StakingBalanceViewProtocol?
    private let accountAddress: AccountAddress

    var controllerAccount: AccountItem?
    var stashAccount: AccountItem?
    private var stashItem: StashItem?
    private var activeEra: EraIndex?
    private var stakingLedger: StakingLedger?
    private var priceData: PriceData?
    var electionStatus: ElectionStatus?

    init(
        interactor: StakingBalanceInteractorInputProtocol,
        wireframe: StakingBalanceWireframeProtocol,
        viewModelFactory: StakingBalanceViewModelFactoryProtocol,
        accountAddress: AccountAddress
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.accountAddress = accountAddress
    }

    private func updateView() {
        guard
            let stakingLedger = stakingLedger,
            let activeEra = activeEra
        else { return }
        let balanceData = StakingBalanceData(stakingLedger: stakingLedger, activeEra: activeEra, priceData: priceData)
        let viewModel = viewModelFactory.createViewModel(from: balanceData)
        view?.reload(with: viewModel)
    }

    var electionPeriodIsClosed: Bool {
        switch electionStatus {
        case .close:
            return true
        case .open:
            return false
        case .none:
            return false
        }
    }

    var controllerAccountIsAvailable: Bool {
        controllerAccount != nil
    }

    var stashAccountIsAvailable: Bool {
        stashAccount != nil
    }

    var unbondingRequestsLimitExceeded: Bool {
        guard let stakingLedger = stakingLedger else { return false }
        return stakingLedger.unlocking.count >= SubstrateConstants.maxUnbondingRequests
    }

    private func handleBondExtraAction(for view: StakingBalanceViewProtocol, locale: Locale?) {
        guard stashAccountIsAvailable else {
            wireframe.presentMissingStash(
                from: view,
                address: stashItem?.stash ?? "",
                locale: locale
            )
            return
        }

        wireframe.showBondMore(from: view)
    }

    private func handleUnbondAction(for view: StakingBalanceViewProtocol, locale: Locale?) {
        guard controllerAccountIsAvailable else {
            wireframe.presentMissingController(
                from: view,
                address: stashItem?.controller ?? "",
                locale: locale
            )
            return
        }

        guard !unbondingRequestsLimitExceeded else {
            wireframe.presentUnbondingLimitReached(from: view, locale: locale)
            return
        }

        wireframe.showUnbond(from: view)
    }

    private func handleRedeemAction(for view: StakingBalanceViewProtocol, locale: Locale?) {
        guard controllerAccountIsAvailable else {
            wireframe.presentMissingController(
                from: view,
                address: stashItem?.controller ?? "",
                locale: locale
            )
            return
        }

        wireframe.showRedeem(from: view)
    }
}

extension StakingBalancePresenter: StakingBalancePresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func handleAction(_ action: StakingBalanceAction) {
        guard let view = view else { return }
        let selectedLocale = view.localizationManager?.selectedLocale

        guard electionPeriodIsClosed else {
            wireframe.presentElectionPeriodIsNotClosed(from: view, locale: selectedLocale)
            return
        }

        switch action {
        case .bondMore:
            handleBondExtraAction(for: view, locale: selectedLocale)
        case .unbond:
            handleUnbondAction(for: view, locale: selectedLocale)
        case .redeem:
            handleRedeemAction(for: view, locale: selectedLocale)
        }
    }

    func handleUnbondingMoreAction() {
        let locale = view?.localizationManager?.selectedLocale
        let actions = StakingRebondOption.allCases.map { option -> AlertPresentableAction in
            let title = option.titleForLocale(locale)
            let action = AlertPresentableAction(title: title) { [weak self] in
                self?.wireframe.showRebond(from: self?.view, option: option)
            }
            return action
        }

        let title = R.string.localizable.walletBalanceUnbonding(preferredLanguages: locale?.rLanguages)
        let closeTitle = R.string.localizable.commonCancel(preferredLanguages: locale?.rLanguages)
        let viewModel = AlertPresentableViewModel(
            title: title,
            message: nil,
            actions: actions,
            closeAction: closeTitle
        )

        wireframe.present(viewModel: viewModel, style: .actionSheet, from: view)
    }
}

extension StakingBalancePresenter: StakingBalanceInteractorOutputProtocol {
    func didReceive(ledgerResult: Result<StakingLedger?, Error>) {
        switch ledgerResult {
        case let .success(ledger):
            stakingLedger = ledger
            updateView()
        case .failure:
            stakingLedger = nil
            updateView()
        }
    }

    func didReceive(activeEraResult: Result<EraIndex?, Error>) {
        switch activeEraResult {
        case let .success(activeEra):
            self.activeEra = activeEra
            updateView()
        case .failure:
            activeEra = nil
            updateView()
        }
    }

    func didReceive(priceResult: Result<PriceData?, Error>) {
        switch priceResult {
        case let .success(priceData):
            self.priceData = priceData
            updateView()
        case .failure:
            priceData = nil
            updateView()
        }
    }

    func didReceive(electionStatusResult: Result<ElectionStatus?, Error>) {
        switch electionStatusResult {
        case let .success(electionStatus):
            self.electionStatus = electionStatus
        case .failure:
            electionStatus = nil
        }
    }

    func didReceive(stashItemResult: Result<StashItem?, Error>) {
        switch stashItemResult {
        case let .success(stashItem):
            self.stashItem = stashItem
            if stashItem == nil {
                wireframe.cancel(from: view)
            }
        case .failure:
            stashItem = nil
        }
    }

    func didReceive(controllerResult: Result<AccountItem?, Error>) {
        switch controllerResult {
        case let .success(controller):
            controllerAccount = controller
        case .failure:
            controllerAccount = nil
        }
    }

    func didReceive(stashResult: Result<AccountItem?, Error>) {
        switch stashResult {
        case let .success(stash):
            stashAccount = stash
        case .failure:
            stashAccount = nil
        }
    }
}
