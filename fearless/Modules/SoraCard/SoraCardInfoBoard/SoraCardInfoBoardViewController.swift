import UIKit
import SoraFoundation

final class SoraCardInfoBoardViewController: UIViewController, ViewHolder {
    typealias RootViewType = SoraCardInfoBoardViewLayout

    // MARK: Private properties

    private let output: SoraCardInfoBoardViewOutput

    // MARK: - Constructor

    init(
        output: SoraCardInfoBoardViewOutput,
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
        view = SoraCardInfoBoardViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)
        setupActions()
    }

    // MARK: - Private methods

    private func setupActions() {
        rootView.hideButton.addTarget(
            self,
            action: #selector(hideButtonClicked),
            for: .touchUpInside
        )
        rootView.statusButton.addTarget(
            self,
            action: #selector(getSoraCardButtonClicked),
            for: .touchUpInside
        )
    }

    @objc private func hideButtonClicked() {
        output.didTapHide()
    }

    @objc private func getSoraCardButtonClicked() {
        output.didTapGetSoraCard()
    }
}

// MARK: - SoraCardInfoBoardViewInput

extension SoraCardInfoBoardViewController: SoraCardInfoBoardViewInput {
    func didReceive(stateViewModel: SoraCardInfoViewModel) {
        rootView.bind(viewModel: stateViewModel)
    }
}

// MARK: - Localizable

extension SoraCardInfoBoardViewController: Localizable {
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}
