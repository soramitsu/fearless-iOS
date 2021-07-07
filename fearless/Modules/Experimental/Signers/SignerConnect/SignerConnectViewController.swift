import UIKit
import SoraFoundation

final class SignerConnectViewController: UIViewController, ViewHolder {
    typealias RootViewType = SignerConnectViewLayout

    let presenter: SignerConnectPresenterProtocol

    private var iconViewModel: ImageViewModelProtocol?

    init(presenter: SignerConnectPresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = SignerConnectViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        configure()
        setupLocalization()
        presenter.setup()
    }

    private func configure() {
        rootView.accountView.addTarget(self, action: #selector(actionDidSelectAccount), for: .touchUpInside)
        rootView.statusView.addTarget(self, action: #selector(actionDidSelectStatus), for: .touchUpInside)
    }

    private func setupLocalization() {
        title = R.string.localizable.signerBeaconTitle(preferredLanguages: selectedLocale.rLanguages)
        rootView.locale = selectedLocale
    }

    @objc private func actionDidSelectAccount() {
        presenter.presentAccountOptions()
    }

    @objc private func actionDidSelectStatus() {
        presenter.presentConnectionDetails()
    }
}

extension SignerConnectViewController: SignerConnectViewProtocol {
    func didReceive(viewModel: SignerConnectViewModel) {
        iconViewModel?.cancel(on: rootView.appView.iconView)
        rootView.appView.iconView.image = nil

        let size = CGSize(
            width: IconWithSubtitleView.Constants.iconSize,
            height: IconWithSubtitleView.Constants.iconSize
        )

        iconViewModel = viewModel.icon
        viewModel.icon?.loadImage(on: rootView.appView.iconView, targetSize: size, animated: true)

        rootView.appView.subtitleLabel.text = viewModel.title
        rootView.connectionInfoView.valueLabel.text = viewModel.connection

        rootView.accountView.subtitle = viewModel.accountName
        rootView.accountView.iconImage = viewModel.accountIcon.imageWithFillColor(
            R.color.colorWhite()!,
            size: UIConstants.smallAddressIconSize,
            contentScale: UIScreen.main.scale
        )

        rootView.setNeedsLayout()
    }

    func didReceive(status: SignerConnectStatus) {
        switch status {
        case .active:
            rootView.statusView.detailsLabel.text = R.string.localizable.signerConnectStatusActive(
                preferredLanguages: selectedLocale.rLanguages
            )
            rootView.statusView.statusIndicatorView.fillColor = R.color.colorGreen()!
        case .connecting:
            rootView.statusView.detailsLabel.text = R.string.localizable.signerConnectStatusConnecting(
                preferredLanguages: selectedLocale.rLanguages
            )
            rootView.statusView.statusIndicatorView.fillColor = R.color.colorLightGray()!
        case .inactive:
            rootView.statusView.detailsLabel.text = R.string.localizable.signerConnectStatusInactive(
                preferredLanguages: selectedLocale.rLanguages
            )
            rootView.statusView.statusIndicatorView.fillColor = R.color.colorLightGray()!
        case .failed:
            rootView.statusView.detailsLabel.text = R.string.localizable.signerConnectStatusFailed(
                preferredLanguages: selectedLocale.rLanguages
            )
            rootView.statusView.statusIndicatorView.fillColor = R.color.colorRed()!
        }
    }
}

extension SignerConnectViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
