import SoraFoundation
import Darwin

final class StakingBalancePresenter {
    let interactor: StakingBalanceInteractorInputProtocol
    let wireframe: StakingBalanceWireframeProtocol
    let viewModelFactory: StakingBalanceViewModelFactoryProtocol
    let viewModelState: StakingBalanceViewModelState
    weak var view: StakingBalanceViewProtocol?
    let dataValidatingFactory: StakingDataValidatingFactoryProtocol
    let chainAsset: ChainAsset
    let wallet: MetaAccountModel

    private var priceData: PriceData?

    init(
        interactor: StakingBalanceInteractorInputProtocol,
        wireframe: StakingBalanceWireframeProtocol,
        viewModelFactory: StakingBalanceViewModelFactoryProtocol,
        viewModelState: StakingBalanceViewModelState,
        dataValidatingFactory: StakingDataValidatingFactoryProtocol,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.dataValidatingFactory = dataValidatingFactory
        self.chainAsset = chainAsset
        self.wallet = wallet
        self.viewModelState = viewModelState
    }

    private func updateView() {
        guard let viewModel = viewModelFactory.buildViewModel(viewModelState: viewModelState) else {
            return
        }

        view?.reload(with: viewModel)
    }

    private func handleBondExtraAction(for _: StakingBalanceViewProtocol, locale _: Locale?) {
        // TODO: Move datavalidators to viewmodelstate

//        DataValidationRunner(validators: [
//            dataValidatingFactory.has(
//                stash: stashAccount,
//                for: stashItem?.stash ?? "",
//                locale: locale ?? Locale.current
//            )
//        ]).runValidation { [weak self] in
//            guard let self = self else {
//                return
//            }
//            self.wireframe.showBondMore(
//                from: view,
//                chain: self.chain,
//                asset: self.asset,
//                selectedAccount: self.selectedAccount
//            )
//        }
    }

    private func handleUnbondAction(for _: StakingBalanceViewProtocol, locale _: Locale?) {
        // TODO: Move datavalidators to viewmodelstate

//        let locale = locale ?? Locale.current
//
//        DataValidationRunner(validators: [
//            dataValidatingFactory.has(
//                controller: controllerAccount,
//                for: stashItem?.controller ?? "",
//                locale: locale
//            ),
//
//            dataValidatingFactory.unbondingsLimitNotReached(
//                stakingLedger?.unlocking.count,
//                locale: locale
//            )
//        ]).runValidation { [weak self] in
//            guard let self = self else {
//                return
//            }
//            self.wireframe.showUnbond(
//                from: view,
//                chain: self.chain,
//                asset: self.asset,
//                selectedAccount: self.selectedAccount
//            )
//        }
    }

    private func handleRedeemAction(for _: StakingBalanceViewProtocol, locale _: Locale?) {
        // TODO: Move datavalidators to viewmodelstate
//        DataValidationRunner(validators: [
//            dataValidatingFactory.has(
//                controller: controllerAccount,
//                for: stashItem?.controller ?? "",
//                locale: locale ?? Locale.current
//            )
//        ]).runValidation { [weak self] in
//            guard let self = self else {
//                return
//            }
//
//            self.wireframe.showRedeem(
//                from: view,
//                chain: self.chain,
//                asset: self.asset,
//                selectedAccount: self.selectedAccount
//            )
//        }
    }

    private func presentRebond(for view: StakingBalanceViewProtocol, locale: Locale?) {
        let actions = StakingRebondOption.allCases.map { option -> AlertPresentableAction in
            let title = option.titleForLocale(locale)
            let action = AlertPresentableAction(title: title) { [weak self] in
                guard let self = self else {
                    return
                }

                self.wireframe.showRebond(
                    from: view,
                    option: option,
                    chain: self.chainAsset.chain,
                    asset: self.chainAsset.asset,
                    selectedAccount: self.wallet
                )
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
        // TODO: Move datavalidators to viewmodelstate
//        let locale = view?.localizationManager?.selectedLocale ?? Locale.current
//
//        DataValidationRunner(validators: [
//            dataValidatingFactory.has(
//                controller: controllerAccount,
//                for: stashItem?.controller ?? "",
//                locale: locale
//            )
//        ]).runValidation { [weak self] in
//            guard let view = self?.view else {
//                return
//            }
//
//            self?.presentRebond(for: view, locale: locale)
//        }
    }
}

extension StakingBalancePresenter: StakingBalanceInteractorOutputProtocol {
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
}

extension StakingBalancePresenter: StakingBalanceModelStateListener {
    func modelStateDidChanged(viewModelState _: StakingBalanceViewModelState) {
        updateView()
    }

    func didReceiveError(error _: StakingBalanceFlowError) {}

    func finishFlow() {
        wireframe.cancel(from: view)
    }
}
