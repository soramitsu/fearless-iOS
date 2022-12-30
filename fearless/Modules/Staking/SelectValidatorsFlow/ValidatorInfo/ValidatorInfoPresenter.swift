import Foundation
import SoraFoundation

final class ValidatorInfoPresenter {
    weak var view: ValidatorInfoViewProtocol?
    let interactor: ValidatorInfoInteractorInputProtocol
    let wireframe: ValidatorInfoWireframeProtocol

    private let viewModelFactory: ValidatorInfoViewModelFactoryProtocol
    private let viewModelState: ValidatorInfoViewModelState
    private let chainAsset: ChainAsset
    private let logger: LoggerProtocol?

    private(set) var priceDataResult: Result<PriceData?, Error>?

    init(
        interactor: ValidatorInfoInteractorInputProtocol,
        wireframe: ValidatorInfoWireframeProtocol,
        viewModelFactory: ValidatorInfoViewModelFactoryProtocol,
        viewModelState: ValidatorInfoViewModelState,
        chainAsset: ChainAsset,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.viewModelState = viewModelState
        self.chainAsset = chainAsset
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
        do {
            let priceData = try priceDataResult?.get()

            if let viewModel = viewModelFactory.buildViewModel(
                viewModelState: viewModelState,
                priceData: priceData,
                locale: selectedLocale
            ) {
                view?.didRecieve(state: .validatorInfo(viewModel))
            } else {
                view?.didRecieve(state: .empty)
            }

        } catch {
            logger?.error("Did receive error: \(error)")

            let error = R.string.localizable.commonErrorNoDataRetrieved(
                preferredLanguages: selectedLocale.rLanguages
            )

            view?.didRecieve(state: .error(error))
        }
    }
}

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
        let priceData = try? priceDataResult?.get()

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

extension ValidatorInfoPresenter: ValidatorInfoInteractorOutputProtocol {
    func didReceivePriceData(result: Result<PriceData?, Error>) {
        priceDataResult = result
        updateView()
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
