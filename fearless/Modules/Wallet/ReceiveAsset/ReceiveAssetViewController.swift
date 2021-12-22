import UIKit
import SoraFoundation

final class ReceiveAssetViewController: UIViewController, ViewHolder {
    typealias RootViewType = ReceiveAssetViewLayout

    let presenter: ReceiveAssetPresenterProtocol

    init(presenter: ReceiveAssetPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = ReceiveAssetViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()

        rootView.navigationBar.backButton.addTarget(
            self,
            action: #selector(closeButtonClicked),
            for: .touchUpInside
        )

        rootView.shareButton.addTarget(
            self,
            action: #selector(shareButtonClicked),
            for: .touchUpInside
        )
    }

    @objc private func closeButtonClicked() {
        presenter.didTapCloseButton()
    }

    @objc private func shareButtonClicked() {
        if let image = rootView.imageView.image {
            presenter.share(qrImage: image)
        }
    }
}

extension ReceiveAssetViewController: ReceiveAssetViewProtocol {
    func bind(viewModel: ReceiveAssetViewModel) {
        rootView.navigationLabel.text =
            R.string.localizable.walletReceiveNavigationTitle(viewModel.asset, preferredLanguages: selectedLocale.rLanguages)
        rootView.accountView.titleLabel.text = viewModel.accountName
        rootView.accountView.subtitleLabel?.text = viewModel.address
        rootView.accountView.iconImage = viewModel.accountIcon
    }

    func didReceive(image: UIImage) {
        rootView.imageView.image = image
    }
}

extension ReceiveAssetViewController: Localizable {
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}

extension ReceiveAssetViewController: HiddableBarWhenPushed {}
