import UIKit
import SoraFoundation

final class KYCMainViewController: UIViewController, ViewHolder {
    typealias RootViewType = KYCMainViewLayout

    // MARK: Private properties

    private let output: KYCMainViewOutput

    // MARK: - Constructor

    init(
        output: KYCMainViewOutput,
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
        view = KYCMainViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)
        setupActions()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        output.willDisappear()
    }

    // MARK: - Private methods

    private func setupActions() {
        rootView.unsupportedCountriesButton.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.output.didTapUnsupportedCountriesList()
        }
        rootView.actionButton.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.rootView.actionButton.sora.isEnabled = false
            self?.output.didTapGetMoreXor()
            self?.rootView.actionButton.sora.isEnabled = true
        }
        rootView.issueCardButton.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.rootView.issueCardButton.sora.isEnabled = false
            self?.output.didTapIssueCard()
            self?.rootView.issueCardButton.sora.isEnabled = true
        }
        rootView.haveCardButton.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.rootView.haveCardButton.sora.isEnabled = false
            self?.output.didTapHaveCard()
            self?.rootView.haveCardButton.sora.isEnabled = true
        }
    }
}

// MARK: - KYCMainViewInput

extension KYCMainViewController: KYCMainViewInput {
    func updateHaveCardButton(isHidden: Bool) {
        rootView.updateHaveCardButton(isHidden: isHidden)
    }

    func set(viewModel: KYCMainViewModel) {
        rootView.set(viewModel: viewModel)
        if viewModel.hasFreeAttempts {
            if viewModel.hasEnoughBalance {
                rootView.actionButton.sora.removeAllHandlers(for: .touchUpInside)
                rootView.actionButton.sora.addHandler(for: .touchUpInside) { [weak self] in
                    self?.rootView.actionButton.sora.isEnabled = false
                    self?.output.didTapIssueCardForFree()
                    self?.rootView.actionButton.sora.isEnabled = true
                }
            } else {
                rootView.actionButton.sora.removeAllHandlers(for: .touchUpInside)
                rootView.actionButton.sora.addHandler(for: .touchUpInside) { [weak self] in
                    self?.rootView.actionButton.sora.isEnabled = false
                    self?.output.didTapGetMoreXor()
                    self?.rootView.actionButton.sora.isEnabled = true
                }
            }
        } else {
            rootView.actionButton.sora.removeAllHandlers(for: .touchUpInside)
            rootView.actionButton.sora.addHandler(for: .touchUpInside) { [weak self] in
                self?.rootView.actionButton.sora.isEnabled = false
                self?.output.didTapIssueCard()
                self?.rootView.actionButton.sora.isEnabled = true
            }
        }
    }
}

// MARK: - Localizable

extension KYCMainViewController: Localizable {
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}
