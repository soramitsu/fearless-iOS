import UIKit

final class WarningAlertViewController: UIViewController, ViewHolder {
    typealias RootViewType = WarningAlertViewLayout

    private let presenter: WarningAlertPresenterProtocol

    init(presenter: WarningAlertPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)

        modalPresentationStyle = .custom
        transitioningDelegate = self
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = WarningAlertViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.didLoad(view: self)

        view.translatesAutoresizingMaskIntoConstraints = false

        rootView.closeButton.addTarget(
            self,
            action: #selector(closeButtonClicked),
            for: .touchUpInside
        )

        rootView.actionButton.addTarget(
            self,
            action: #selector(actionButtonClicked),
            for: .touchUpInside
        )
    }

    @objc private func actionButtonClicked() {
        presenter.didTapActionButton()
    }

    @objc private func closeButtonClicked() {
        presenter.didTapCloseButton()
    }
}

extension WarningAlertViewController: WarningAlertViewProtocol {
    func didReceive(config: WarningAlertConfig) {
        rootView.bind(viewModel: config)
    }
}

extension WarningAlertViewController: UIViewControllerTransitioningDelegate {
    func animationController(
        forPresented _: UIViewController,
        presenting _: UIViewController,
        source _: UIViewController
    ) -> UIViewControllerAnimatedTransitioning? {
        WarningAlertPresentAnimator()
    }

    func animationController(forDismissed _: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        WarningAlertDismissAnimator()
    }
}
