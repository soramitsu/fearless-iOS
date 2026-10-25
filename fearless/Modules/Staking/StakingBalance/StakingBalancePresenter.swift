import SoraFoundation
import Darwin
import SSFModels

final class StakingBalancePresenter {
    let interactor: StakingBalanceInteractorInputProtocol
    let wireframe: StakingBalanceWireframeProtocol
    let viewModelFactory: StakingBalanceViewModelFactoryProtocol
    let viewModelState: StakingBalanceViewModelState
    weak var view: StakingBalanceViewProtocol?
    let dataValidatingFactory: StakingDataValidatingFactoryProtocol
    let chainAsset: ChainAsset
    let wallet: MetaAccountModel

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
        guard let viewModel = viewModelFactory.buildViewModel(
            viewModelState: viewModelState,
            priceData: chainAsset.asset.getPrice(for: wallet.selectedCurrency)
        ) else {
            return
        }

        view?.reload(with: viewModel)
    }

    private func handleBondExtraAction(for view: StakingBalanceViewProtocol, locale: Locale?) {
        guard let flow = viewModelState.bondMoreFlow else {
            return
        }

        let locale = locale ?? Locale.current
        DataValidationRunner(
            validators: viewModelState.stakeMoreValidators(using: locale)
        ).runValidation { [weak self] in
            guard let strongSelf = self else {
                return
            }

            strongSelf.wireframe.showBondMore(
                from: view,
                chainAsset: strongSelf.chainAsset,
                wallet: strongSelf.wallet,
                flow: flow
            )
        }
    }

    private func handleUnbondAction(for view: StakingBalanceViewProtocol, locale: Locale?) {
        guard let flow = viewModelState.unbondFlow else {
            return
        }

        let locale = locale ?? Locale.current

        DataValidationRunner(
            validators: viewModelState.stakeLessValidators(using: locale)
        ).runValidation { [weak self] in
            guard let strongSelf = self else {
                return
            }

            strongSelf.wireframe.showUnbond(
                from: view,
                chainAsset: strongSelf.chainAsset,
                wallet: strongSelf.wallet,
                flow: flow
            )
        }
    }

    private func handleRedeemAction(for view: StakingBalanceViewProtocol, locale: Locale?) {
        guard let flow = viewModelState.revokeFlow else {
            return
        }

        let locale = locale ?? Locale.current
        DataValidationRunner(validators: viewModelState.revokeValidators(using: locale)).runValidation { [weak self] in
            guard let strongSelf = self else {
                return
            }

            strongSelf.wireframe.showRedeem(
                from: view,
                chainAsset: strongSelf.chainAsset,
                wallet: strongSelf.wallet,
                flow: flow
            )
        }
    }

    private func presentRebond(for view: StakingBalanceViewProtocol, locale: Locale?) {
        let actions = viewModelState.rebondCases.map { option -> SheetAlertPresentableAction in
            let title = option.titleForLocale(locale)
            let action = SheetAlertPresentableAction(title: title) { [weak self] in
                guard let self = self else {
                    return
                }

                self.viewModelState.decideRebondFlow(option: option)
            }

            return action
        }

        let title = R.string.localizable.walletBalanceUnbonding_v190(preferredLanguages: locale?.rLanguages)
        let closeTitle = R.string.localizable.commonCancel(preferredLanguages: locale?.rLanguages)
        let viewModel = SheetAlertPresentableViewModel(
            title: title,
            message: nil,
            actions: actions,
            closeAction: closeTitle,
            icon: R.image.iconWarningBig()
        )

        wireframe.present(viewModel: viewModel, from: view)
    }
}

extension StakingBalancePresenter: StakingBalanceInteractorOutputProtocol {}

extension StakingBalancePresenter: StakingBalancePresenterProtocol {
    func setup() {
        viewModelState.setStateListener(self)

        interactor.setup()
    }

    func handleRefresh() {
        interactor.refresh()
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

        DataValidationRunner(
            validators: viewModelState.unbondingMoreValidators(using: locale)
        ).runValidation { [weak self] in
            guard let view = self?.view else {
                return
            }

            self?.presentRebond(for: view, locale: locale)
        }
    }
}

extension StakingBalancePresenter: StakingBalanceModelStateListener {
    func modelStateDidChanged(viewModelState _: StakingBalanceViewModelState) {
        updateView()
    }

    func finishFlow() {
        wireframe.cancel(from: view)
    }

    func decideShowSetupRebondFlow() {
        wireframe.showRebondSetup(
            from: view,
            chainAsset: chainAsset,
            wallet: wallet
        )
    }

    func decideShowConfirmRebondFlow(flow: StakingRebondConfirmationFlow) {
        wireframe.showRebondConfirm(
            from: view,
            chainAsset: chainAsset,
            wallet: wallet,
            flow: flow
        )
    }
}
