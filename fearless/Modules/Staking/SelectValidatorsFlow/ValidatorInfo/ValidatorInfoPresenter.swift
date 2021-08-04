import Foundation
import SoraFoundation

final class ValidatorInfoPresenter {
    weak var view: ValidatorInfoViewProtocol?
    let interactor: ValidatorInfoInteractorInputProtocol
    let wireframe: ValidatorInfoWireframeProtocol

    private let viewModelFactory: ValidatorInfoViewModelFactoryProtocol
    private let chain: Chain
    private let logger: LoggerProtocol?

    private(set) var validatorInfoResult: Result<ValidatorInfoProtocol?, Error>?
    private(set) var priceDataResult: Result<PriceData?, Error>?

    init(
        interactor: ValidatorInfoInteractorInputProtocol,
        wireframe: ValidatorInfoWireframeProtocol,
        viewModelFactory: ValidatorInfoViewModelFactoryProtocol,
        chain: Chain,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.chain = chain
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
        guard let validatorInfoResult = self.validatorInfoResult else {
            view?.didRecieve(state: .empty)
            return
        }

        do {
            let priceData = try priceDataResult?.get()

            if let validatorInfo = try validatorInfoResult.get() {
                let viewModel = viewModelFactory.createViewModel(
                    from: validatorInfo,
                    priceData: priceData,
                    locale: selectedLocale
                )

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
        interactor.setup()
    }

    func reload() {
        interactor.reload()
    }

    func presentAccountOptions() {
        if let view = view, let validatorInfo = try? validatorInfoResult?.get() {
            wireframe.presentAccountOptions(
                from: view,
                address: validatorInfo.address,
                chain: chain,
                locale: selectedLocale
            )
        }
    }

    func presentTotalStake() {
        guard let validatorInfo = try? validatorInfoResult?.get() else { return }

        let priceData = try? priceDataResult?.get()

        wireframe.showStakingAmounts(
            from: view,
            items: viewModelFactory.createStakingAmountsViewModel(
                from: validatorInfo,
                priceData: priceData
            )
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

    func didStartLoadingValidatorInfo() {
        view?.didRecieve(state: .loading)
    }

    func didReceiveValidatorInfo(result: Result<ValidatorInfoProtocol?, Error>) {
        validatorInfoResult = result
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
