import UIKit
import SoraFoundation
import SoraUI
import SSFModels

final class AllDoneViewController: UIViewController, ViewHolder, UIAdaptivePresentationControllerDelegate {
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

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        output.presentationControllerWillDismiss()
    }

    // MARK: - Private methods

    private func setup() {
        rootView.closeButton.addTarget(self, action: #selector(dismissSelf), for: .touchUpInside)
        rootView.copyOnTap = { [weak self] in
            self?.output.didCopyTapped()
        }
        rootView.subscanButton.addTarget(self, action: #selector(handleSubscanTapped), for: .touchUpInside)
        rootView.shareButton.addTarget(self, action: #selector(handleShareTapped), for: .touchUpInside)
    }

    // MARK: - Private actions

    @objc private func dismissSelf() {
        output.dismiss()
    }

    @objc private func handleSubscanTapped() {
        output.subscanButtonDidTapped()
    }

    @objc private func handleShareTapped() {
        output.shareButtonDidTapped()
    }
}

// MARK: - AllDoneViewInput

extension AllDoneViewController: AllDoneViewInput {
    func didReceive(viewModel: AllDoneViewModel) {
        rootView.bind(viewModel)
    }

    func didReceive(explorer: ChainModel.ExternalApiExplorer?) {
        rootView.updateState(for: explorer)
    }
}

// MARK: - Localizable

extension AllDoneViewController: Localizable {
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}
