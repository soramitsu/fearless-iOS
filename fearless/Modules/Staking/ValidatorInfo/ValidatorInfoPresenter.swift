import Foundation
import CommonWallet

final class ValidatorInfoPresenter {
    weak var view: ValidatorInfoViewProtocol?
    var interactor: ValidatorInfoInteractorInputProtocol!
    var wireframe: ValidatorInfoWireframeProtocol!

    private let locale: Locale
    private let viewModelFactory: ValidatorInfoViewModelFactoryProtocol
    private let asset: WalletAsset
    private let logger: LoggerProtocol?

    private(set) var validatorInfo: ValidatorInfoProtocol?
    private(set) var priceData: PriceData?

    init(
        viewModelFactory: ValidatorInfoViewModelFactoryProtocol,
        asset: WalletAsset,
        locale: Locale,
        logger: LoggerProtocol? = nil
    ) {
        self.viewModelFactory = viewModelFactory
        self.asset = asset
        self.locale = locale
        self.logger = logger
    }

    private func show(_ url: URL) {
        if let view = view {
            wireframe.showWeb(url: url, from: view, style: .automatic)
        }
    }
}

extension ValidatorInfoPresenter: ValidatorInfoPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func presentAccountOptions() {
        if let view = view,
           let chain = WalletAssetId(rawValue: asset.identifier)?.chain,
           let validatorInfo = self.validatorInfo {
            wireframe.presentAccountOptions(
                from: view,
                address: validatorInfo.address,
                chain: chain,
                locale: locale
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

    func presentStateDescription(for _: ValidatorMyNominationStatus) {
        #warning("Not implemented")
    }

    func activateEmail() {
        guard let email = validatorInfo?.identity?.email else { return }
        guard let view = view else { return }

        let message = SocialMessage(
            body: nil,
            subject: "",
            recepients: [email]
        )
        if !wireframe.writeEmail(with: message, from: view, completionHandler: nil) {
            wireframe.present(
                message: R.string.localizable
                    .noEmailBoundErrorMessage(preferredLanguages: locale.rLanguages),
                title: R.string.localizable
                    .commonErrorGeneralTitle(preferredLanguages: locale.rLanguages),
                closeAction: R.string.localizable
                    .commonClose(preferredLanguages: locale.rLanguages),
                from: view
            )
        }
    }

    func activateWeb() {
        guard let urlString = validatorInfo?.identity?.web else { return }

        if let url = URL(string: urlString) {
            show(url)
        }
    }

    func activateTwitter() {
        guard let account = validatorInfo?.identity?.twitter else { return }

        if let url = URL.twitterAddress(for: account) {
            show(url)
        }
    }

    func activateRiotName() {
        guard let name = validatorInfo?.identity?.riot else { return }

        if let url = URL.riotAddress(for: name) {
            show(url)
        }
    }

    private func updateView() {
        guard let validatorInfo = self.validatorInfo else { return }

        let viewModel = viewModelFactory.createViewModel(
            from: validatorInfo,
            priceData: priceData
        )
        view?.didRecieve(viewModel)
    }
}

extension ValidatorInfoPresenter: ValidatorInfoInteractorOutputProtocol {
    func didReceive(validatorInfo: ValidatorInfoProtocol) {
        self.validatorInfo = validatorInfo
        updateView()
    }

    func didRecieve(priceData: PriceData?) {
        self.priceData = priceData
        updateView()
    }

    func didReceive(priceError: Error) {
        logger?.error("Did receive error: \(priceError)")
    }
}
