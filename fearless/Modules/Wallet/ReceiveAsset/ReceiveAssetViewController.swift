import UIKit
import SoraFoundation

final class ReceiveAssetViewController: UIViewController, ViewHolder {
    typealias RootViewType = ReceiveAssetViewLayout

    let presenter: ReceiveAssetPresenterProtocol

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
        presenter.didTapShareButton()
    }
}

extension ReceiveAssetViewController: Localizable {
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}

extension ReceiveAssetViewController: HiddableBarWhenPushed {}
