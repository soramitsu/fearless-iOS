import UIKit
import SoraFoundation

final class CrowdloanAgreementSignedViewController: UIViewController, ViewHolder {
    typealias RootViewType = CrowdloanAgreementSignedViewLayout

    let presenter: CrowdloanAgreementSignedPresenterProtocol

    init(presenter: CrowdloanAgreementSignedPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = CrowdloanAgreementSignedViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        configure()
        setupLocalization()

        presenter.setup()

        navigationItem.hidesBackButton = true
    }

    private func configure() {
        rootView.continueButton.addTarget(
            self,
            action: #selector(actionContinue),
            for: .touchUpInside
        )

        let tapGestureRecognizer = UITapGestureRecognizer(
            target: self,
            action: #selector(actionTapHash(_:))
        )
        rootView.hashLabel.addGestureRecognizer(tapGestureRecognizer)
    }

    private func setupLocalization() {
        rootView.locale = selectedLocale
    }

    @objc private func actionContinue() {
        presenter.actionContinue()
    }

    @objc private func actionTapHash(_ sender: UIGestureRecognizer) {
        if sender.state == .ended {
            presenter.seeHash()
        }
    }
}

extension CrowdloanAgreementSignedViewController: CrowdloanAgreementSignedViewProtocol {
    func didReceive(viewModel: CrowdloanAgreementSignedViewModel) {
        title = viewModel.title

        rootView.bind(to: viewModel)
    }
}

extension CrowdloanAgreementSignedViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
