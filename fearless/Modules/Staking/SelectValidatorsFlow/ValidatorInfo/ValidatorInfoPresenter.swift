import Foundation
import SoraFoundation

final class ValidatorInfoPresenter {
    weak var view: ValidatorInfoViewProtocol?
    let interactor: ValidatorInfoInteractorInputProtocol
    let wireframe: ValidatorInfoWireframeProtocol

    private let viewModelFactory: ValidatorInfoViewModelFactoryProtocol
    private let chain: Chain
    private let logger: LoggerProtocol?

    private(set) var validatorInfo: ValidatorInfoProtocol?
    private(set) var priceData: PriceData?

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
        guard let validatorInfo = self.validatorInfo else { return }

        let viewModel = viewModelFactory.createViewModel(
            from: validatorInfo,
            priceData: priceData,
            locale: selectedLocale
        )

        view?.didRecieve(viewModel: viewModel)
    }
}

extension ValidatorInfoPresenter: ValidatorInfoPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func presentAccountOptions() {
        if let view = view, let validatorInfo = validatorInfo {
            wireframe.presentAccountOptions(
                from: view,
                address: validatorInfo.address,
                chain: chain,
                locale: selectedLocale
            )
        }
    }

    func presentTotalStake() {
        guard let validatorInfo = validatorInfo else { return }

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
        switch result {
        case let .success(priceData):
            self.priceData = priceData
            updateView()
        case let .failure(error):
            logger?.error("Did receive price data error: \(error)")
        }
    }

    func didReceive(validatorInfo: ValidatorInfoProtocol) {
        self.validatorInfo = validatorInfo
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
