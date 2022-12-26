import UIKit
import SoraFoundation

final class VerificationStatusViewController: UIViewController, ViewHolder {
    typealias RootViewType = VerificationStatusViewLayout

    // MARK: Private properties

    private let output: VerificationStatusViewOutput

    // MARK: - Constructor

    init(
        output: VerificationStatusViewOutput,
        localizationManager: LocalizationManagerProtocol?
    ) {
        self.output = output
        super.init(nibName: nil, bundle: nil)
        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Life cycle

    override func loadView() {
        view = VerificationStatusViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)
    }

    // MARK: - Private methods

    private func configureActions(for status: SoraCardStatus) {
        switch status {
        case .success, .failure, .pending:
            output.didTapCloseButton()
        case .rejected:
            output.didTapTryagainButton()
        }
    }
}

// MARK: - VerificationStatusViewInput

extension VerificationStatusViewController: VerificationStatusViewInput {
    func didReceive(status: SoraCardStatus) {
        rootView.bind(status: status)
    }
}

// MARK: - Localizable

extension VerificationStatusViewController: Localizable {
    func applyLocalization() {}
}
