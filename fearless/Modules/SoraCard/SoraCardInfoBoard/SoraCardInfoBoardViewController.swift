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
    }

    // MARK: - Private methods

    private func setupActions(with state: SoraCardState) {
        rootView.statusButton.removeTarget(self, action: nil, for: .touchUpInside)

        switch state {
        case .none:
            rootView.statusButton.addTarget(
                self,
                action: #selector(getSoraCardButtonClicked),
                for: .touchUpInside
            )
        case .verification, .verificationFailed, .rejected, .onway:
            rootView.statusButton.addTarget(
                self,
                action: #selector(kycStatusButtonClicked),
                for: .touchUpInside
            )
        case .active:
            rootView.statusButton.addTarget(
                self,
                action: #selector(balanceButtonClicked),
                for: .touchUpInside
            )
        case .error:
            rootView.statusButton.addTarget(
                self,
                action: #selector(refreshButtonClicked),
                for: .touchUpInside
            )
        }
    }

    @objc private func getSoraCardButtonClicked() {
        output.didTapGetSoraCard()
    }

    @objc private func kycStatusButtonClicked() {
        output.didTapKYCStatus()
    }

    @objc private func balanceButtonClicked() {
        output.didTapBalance()
    }

    @objc private func refreshButtonClicked() {
        output.didTapRefresh()
    }
}

// MARK: - SoraCardInfoBoardViewInput

extension SoraCardInfoBoardViewController: SoraCardInfoBoardViewInput {
    func didReceive(stateViewModel: LocalizableResource<SoraCardInfoViewModel>) {
        setupActions(with: stateViewModel.value(for: Locale.current).state)

        rootView.bind(viewModel: stateViewModel)
    }
}

// MARK: - Localizable

extension SoraCardInfoBoardViewController: Localizable {
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}
