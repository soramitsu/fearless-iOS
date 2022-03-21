import UIKit
import SoraFoundation

class RootViewController: UIViewController, ViewHolder {
    typealias RootViewType = RootViewLayout

    let presenter: RootPresenterProtocol
    var state: RootViewState = .plain

    init(presenter: RootPresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = RootViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        rootView.actionButton.addTarget(
            self,
            action: #selector(retryButtonClicked),
            for: .touchUpInside
        )
    }

    @objc private func retryButtonClicked() {
        presenter.didTapRetryButton(from: state)
    }

    private func applyState() {
        switch state {
        case .plain:
            rootView.infoView.isHidden = true
        case let .retry(viewModel):
            rootView.infoView.isHidden = false
            rootView.bind(viewModel: viewModel)
        case let .update(viewModel):
            rootView.infoView.isHidden = false
            rootView.bind(viewModel: viewModel)
        }
    }
}

extension RootViewController: RootViewProtocol {
    func didReceive(state: RootViewState) {
        self.state = state
        applyState()
    }
}

extension RootViewController: Localizable {
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}
