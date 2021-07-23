import SoraFoundation

final class StakingBalancePresenter {
    let interactor: StakingBalanceInteractorInputProtocol
    let wireframe: StakingBalanceWireframeProtocol
    let viewModelFactory: StakingBalanceViewModelFactoryProtocol
    weak var view: StakingBalanceViewProtocol?
    let accountAddress: AccountAddress
    let dataValidatingFactory: StakingDataValidatingFactoryProtocol

    var controllerAccount: AccountItem?
    var stashAccount: AccountItem?
    var stakingLedger: StakingLedger?
    private var stashItem: StashItem?
    private var activeEra: EraIndex?
    private var priceData: PriceData?
    private var eraCompletionTime: TimeInterval?
    private let countdownTimer: CountdownTimerProtocol

    init(
        interactor: StakingBalanceInteractorInputProtocol,
        wireframe: StakingBalanceWireframeProtocol,
        viewModelFactory: StakingBalanceViewModelFactoryProtocol,
        dataValidatingFactory: StakingDataValidatingFactoryProtocol,
        accountAddress: AccountAddress,
        countdownTimer: CountdownTimerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.dataValidatingFactory = dataValidatingFactory
        self.accountAddress = accountAddress
        self.countdownTimer = countdownTimer
        self.countdownTimer.delegate = self
    }

    deinit {
        countdownTimer.stop()
    }

    private func updateView() {
        guard let stakingLedger = stakingLedger, let activeEra = activeEra else { return }

        let balanceData = StakingBalanceData(
            stakingLedger: stakingLedger,
            activeEra: activeEra,
            priceData: priceData,
            eraCompletionTime: eraCompletionTime
        )

        let viewModel = viewModelFactory.createViewModel(from: balanceData)
        view?.reload(with: viewModel)
    }

    private func handleBondExtraAction(for view: StakingBalanceViewProtocol, locale: Locale?) {
        DataValidationRunner(validators: [
            dataValidatingFactory.has(
                stash: stashAccount,
                for: stashItem?.stash ?? "",
                locale: locale ?? Locale.current
            )
        ]).runValidation { [weak self] in
            self?.wireframe.showBondMore(from: view)
        }
    }

    private func handleUnbondAction(for view: StakingBalanceViewProtocol, locale: Locale?) {
        let locale = locale ?? Locale.current

        DataValidationRunner(validators: [
            dataValidatingFactory.has(
                controller: controllerAccount,
                for: stashItem?.controller ?? "",
                locale: locale
            ),

            dataValidatingFactory.unbondingsLimitNotReached(
                stakingLedger?.unlocking.count,
                locale: locale
            )
        ]).runValidation { [weak self] in
            self?.wireframe.showUnbond(from: view)
        }
    }

    private func handleRedeemAction(for view: StakingBalanceViewProtocol, locale: Locale?) {
        DataValidationRunner(validators: [
            dataValidatingFactory.has(
                controller: controllerAccount,
                for: stashItem?.controller ?? "",
                locale: locale ?? Locale.current
            )
        ]).runValidation { [weak self] in
            self?.wireframe.showRedeem(from: view)
        }
    }

    private func presentRebond(for view: StakingBalanceViewProtocol, locale: Locale?) {
        let actions = StakingRebondOption.allCases.map { option -> AlertPresentableAction in
            let title = option.titleForLocale(locale)
            let action = AlertPresentableAction(title: title) { [weak self] in
                self?.wireframe.showRebond(from: self?.view, option: option)
            }
            return action
        }

        let title = R.string.localizable.walletBalanceUnbonding_v190(preferredLanguages: locale?.rLanguages)
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

extension StakingBalancePresenter: StakingBalancePresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func handleAction(_ action: StakingBalanceAction) {
        guard let view = view else { return }
        let selectedLocale = view.localizationManager?.selectedLocale

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
        let locale = view?.localizationManager?.selectedLocale ?? Locale.current

        DataValidationRunner(validators: [
            dataValidatingFactory.has(
                controller: controllerAccount,
                for: stashItem?.controller ?? "",
                locale: locale
            )
        ]).runValidation { [weak self] in
            guard let view = self?.view else {
                return
            }

            self?.presentRebond(for: view, locale: locale)
        }
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

    func didReceive(eraCountdownResult: Result<EraCountdown, Error>) {
        switch eraCountdownResult {
        case let .success(eraCountdown):
            countdownTimer.stop()
            countdownTimer.start(with: eraCountdown.eraCompletionTime, runLoop: .main, mode: .common)
        case .failure:
            eraCompletionTime = nil
        }
    }
}

extension StakingBalancePresenter: CountdownTimerDelegate {
    func didStart(with remainedInterval: TimeInterval) {
        eraCompletionTime = remainedInterval
        updateView()
    }

    func didCountdown(remainedInterval: TimeInterval) {
        eraCompletionTime = remainedInterval
        updateView()
    }

    func didStop(with _: TimeInterval) {
        updateView()
    }
}
