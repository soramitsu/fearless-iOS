import Foundation
import SoraFoundation
import SSFModels

final class ValidatorInfoPresenter {
    weak var view: ValidatorInfoViewProtocol?
    let interactor: ValidatorInfoInteractorInputProtocol
    let wireframe: ValidatorInfoWireframeProtocol

    private let viewModelFactory: ValidatorInfoViewModelFactoryProtocol
    private let viewModelState: ValidatorInfoViewModelState
    private let chainAsset: ChainAsset
    private let wallet: MetaAccountModel
    private let logger: LoggerProtocol?
    private var viewModel: ValidatorInfoViewModel?

    private var priceData: PriceData? {
        chainAsset.asset.getPrice(for: wallet.selectedCurrency)
    }

    init(
        interactor: ValidatorInfoInteractorInputProtocol,
        wireframe: ValidatorInfoWireframeProtocol,
        viewModelFactory: ValidatorInfoViewModelFactoryProtocol,
        viewModelState: ValidatorInfoViewModelState,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.viewModelState = viewModelState
        self.chainAsset = chainAsset
        self.wallet = wallet
        self.logger = logger
        self.localizationManager = localizationManager
    }

    func activateEmail(_ email: String) {
        guard let view = view else { return }

        let message = SocialMessage(
            body: nil,
            subject: "",
            recepients: [email]
        )
        if !wireframe.writeEmail(with: message, from: view, completionHandler: nil) {
            wireframe.present(
                message: R.string.localizable
                    .noEmailBoundErrorMessage(preferredLanguages: selectedLocale.rLanguages),
                title: R.string.localizable
                    .commonErrorGeneralTitle(preferredLanguages: selectedLocale.rLanguages),
                closeAction: R.string.localizable
                    .commonClose(preferredLanguages: selectedLocale.rLanguages),
                from: view
            )
        }
    }

    private func show(_ url: URL) {
        if let view = view {
            wireframe.showWeb(url: url, from: view, style: .automatic)
        }
    }

    private func updateView() {
        if let viewModel = viewModelFactory.buildViewModel(
            viewModelState: viewModelState,
            priceData: priceData,
            locale: selectedLocale
        ) {
            self.viewModel = viewModel
            view?.didRecieve(state: .validatorInfo(viewModel))
        } else {
            view?.didRecieve(state: .empty)
        }
    }
}

extension ValidatorInfoPresenter: ValidatorInfoInteractorOutputProtocol {}

extension ValidatorInfoPresenter: ValidatorInfoPresenterProtocol {
    func setup() {
        viewModelState.setStateListener(self)

        interactor.setup()
    }

    func reload() {
        interactor.reload()
    }

    func presentAccountOptions() {
        if let view = view, let address = viewModelState.validatorAddress {
            wireframe.presentAccountOptions(
                from: view,
                address: address,
                chain: chainAsset.chain,
                locale: selectedLocale
            )
        }
    }

    func presentTotalStake() {
        guard let viewModel = viewModelFactory.buildStakingAmountViewModels(
            viewModelState: viewModelState,
            priceData: priceData
        ) else {
            return
        }

        wireframe.showStakingAmounts(
            from: view,
            items: viewModel
        )
    }

    func presentMinStake() {
        if case let .elected(exposure) = viewModel?.staking.status, let amount = exposure.minStakeToGetRewards?.amount {
            let text = R.string.localizable.validatorInfoMinStakeAlertText(amount, preferredLanguages: selectedLocale.rLanguages)
            wireframe.presentInfo(message: text, title: "", from: view)
        }
    }

    func presentIdentityItem(_ value: ValidatorInfoViewModel.IdentityItemValue) {
        guard case let .link(value, tag) = value else {
            return
        }

        switch tag {
        case .email:
            activateEmail(value)
        case .web:
            if let url = URL(string: value) {
                show(url)
            }
        case .riot:
            if let url = URL.riotAddress(for: value) {
                show(url)
            }
        case .twitter:
            if let url = URL.twitterAddress(for: value) {
                show(url)
            }
        }
    }
}

extension ValidatorInfoPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            updateView()
        }
    }
}

extension ValidatorInfoPresenter: ValidatorInfoModelStateListener {
    func modelStateDidChanged(viewModelState _: ValidatorInfoViewModelState) {
        updateView()
    }

    func didStartLoading() {
        view?.didRecieve(state: .loading)
    }

    func didReceiveError(error: Error) {
        logger?.error("ValidatorInfoPresenter:didReceiveError: \(error)")
    }
}
