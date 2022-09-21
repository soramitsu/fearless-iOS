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

        rootView.shareButton.addTarget(
            self,
            action: #selector(shareButtonClicked),
            for: .touchUpInside
        )

        rootView.copyButton.addTarget(
            self,
            action: #selector(copyButtonClicked),
            for: .touchUpInside
        )

        navigationController?.setNavigationBarHidden(true, animated: false)
    }

    @objc private func shareButtonClicked() {
        if let image = rootView.qrView.qrImageView.image {
            presenter.share(qrImage: image)
        }
    }

    @objc private func copyButtonClicked() {
        UIPasteboard.general.string = rootView.addressLabel.text
        presenter.close()
    }
}

extension ReceiveAssetViewController: ReceiveAssetViewProtocol {
    func didReceive(viewModel: ReceiveAssetViewModel) {
        rootView.bind(viewModel: viewModel)
    }

    func didReceive(image: UIImage) {
        rootView.qrView.qrImageView.image = image
    }

    func didReceive(locale: Locale) {
        rootView.locale = locale
    }
}

extension ReceiveAssetViewController: HiddableBarWhenPushed {}
