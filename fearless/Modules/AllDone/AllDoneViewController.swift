import UIKit
import SoraFoundation

final class AllDoneViewController: UIViewController, ViewHolder {
    typealias RootViewType = AllDoneViewLayout

    // MARK: Private properties

    private let output: AllDoneViewOutput

    // MARK: - Constructor

    init(
        output: AllDoneViewOutput,
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
        view = AllDoneViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)
        setup()
    }

    // MARK: - Private methods

    private func setup() {
        rootView.closeButton.addTarget(self, action: #selector(dismissSelf), for: .touchUpInside)
        rootView.copyOnTap = { [weak self] in
            self?.output.didCopyTapped()
        }
    }

    // MARK: - Private actions

    @objc private func dismissSelf() {
        output.dismiss()
    }
}

// MARK: - AllDoneViewInput

extension AllDoneViewController: AllDoneViewInput {
    func didReceive(viewModel: AllDoneViewModel) {
        rootView.bind(viewModel)
    }
}

// MARK: - Localizable

extension AllDoneViewController: Localizable {
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}
