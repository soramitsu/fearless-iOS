import UIKit
import SoraFoundation

final class ReceiveAssetViewController: UIViewController, ViewHolder {
    typealias RootViewType = ReceiveAssetViewLayout

    let presenter: ReceiveAssetPresenterProtocol

    init(
        presenter: ReceiveAssetPresenterProtocol
    ) {
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

        rootView.accountView.addTarget(
            self,
            action: #selector(actionAccountOptions),
            for: .touchUpInside
        )

        navigationController?.setNavigationBarHidden(true, animated: false)
    }

    @objc private func closeButtonClicked() {
        presenter.didTapCloseButton()
    }

    @objc private func shareButtonClicked() {
        if let image = rootView.imageView.image {
            presenter.share(qrImage: image)
        }
    }

    @objc func actionAccountOptions() {
        presenter.presentAccountOptions()
    }
}

extension ReceiveAssetViewController: ReceiveAssetViewProtocol {
    func didReceive(viewModel: ReceiveAssetViewModel) {
        rootView.bind(viewModel: viewModel)
    }

    func didReceive(image: UIImage) {
        rootView.imageView.image = image
    }

    func didReceive(locale: Locale) {
        rootView.locale = locale
    }
}

extension ReceiveAssetViewController: HiddableBarWhenPushed {}
