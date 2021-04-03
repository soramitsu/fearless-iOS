import Foundation
import CommonWallet

final class ValidatorInfoPresenter {
    weak var view: ValidatorInfoViewProtocol?
    var interactor: ValidatorInfoInteractorInputProtocol!
    var wireframe: ValidatorInfoWireframeProtocol!

    private let locale: Locale
    private let viewModelFactory: ValidatorInfoViewModelFactoryProtocol
    private let asset: WalletAsset

    private(set) var validatorInfo: ValidatorInfoProtocol?

    init(
        viewModelFactory: ValidatorInfoViewModelFactoryProtocol,
        asset: WalletAsset,
        locale: Locale
    ) {
        self.viewModelFactory = viewModelFactory
        self.asset = asset
        self.locale = locale
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
        // TODO: FLW-652
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
}

extension ValidatorInfoPresenter: ValidatorInfoInteractorOutputProtocol {
    func didReceive(validatorInfo: ValidatorInfoProtocol) {
        self.validatorInfo = validatorInfo

        let accountViewModel = viewModelFactory.createAccountViewModel(from: validatorInfo)
        let extrasViewModel = viewModelFactory.createExtrasViewModel(from: validatorInfo)

        view?.didReceive(
            accountViewModel: accountViewModel,
            extrasViewModel: extrasViewModel
        )
    }
}
