import UIKit
import SoraFoundation
import SnapKit

final class NftSendViewController: UIViewController, ViewHolder, HiddableBarWhenPushed {
    typealias RootViewType = NftSendViewLayout

    // MARK: Private properties

    private let output: NftSendViewOutput

    // MARK: - Constructor

    init(
        output: NftSendViewOutput,
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
        view = NftSendViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)

        rootView.navigationBar.backButton.addAction { [weak self] in
            self?.output.didBackButtonTapped()
        }
        rootView.scanButton.addAction { [weak self] in
            self?.output.didTapScanButton()
        }
        rootView.historyButton.addAction { [weak self] in
            self?.output.didTapHistoryButton()
        }
        rootView.pasteButton.addAction { [weak self] in
            self?.output.didTapPasteButton()
        }
        rootView.actionButton.addAction { [weak self] in
            self?.output.didTapContinueButton()
        }

        rootView.searchView.textField.delegate = self
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupKeyboardHandler()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        clearKeyboardHandler()
    }

    // MARK: - Private methods
}

// MARK: - NftSendViewInput

extension NftSendViewController: NftSendViewInput {
    func didReceive(feeViewModel: BalanceViewModelProtocol?) {
        rootView.bind(feeViewModel: feeViewModel)
    }

    func didReceive(scamInfo: ScamInfo?) {
        rootView.bind(scamInfo: scamInfo)
    }

    func didReceive(viewModel: RecipientViewModel) {
        rootView.bind(viewModel: viewModel)
        rootView.actionButton.set(enabled: viewModel.isValid)
    }
}

// MARK: - Localizable

extension NftSendViewController: Localizable {
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}

extension NftSendViewController: UITextFieldDelegate {
    func textField(
        _ textField: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        if textField == rootView.searchView.textField {
            guard let text = textField.text as NSString? else {
                return true
            }
            let newString = text.replacingCharacters(in: range, with: string)
            output.searchTextDidChanged(newString)
        }
        return false
    }

    func textFieldShouldClear(_ textField: UITextField) -> Bool {
        if textField == rootView.searchView.textField {
            output.searchTextDidChanged("")
        }
        return true
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()

        guard let text = textField.text else {
            return false
        }
        if textField == rootView.searchView.textField {
            output.searchTextDidChanged(text)
        }
        return false
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        let searchIsFirstResponder = textField == rootView.searchView.textField
        rootView.searchView.set(highlighted: searchIsFirstResponder, animated: false)
    }

    func textFieldDidEndEditing(_: UITextField) {
        rootView.searchView.set(highlighted: false, animated: false)
    }
}

extension NftSendViewController: KeyboardViewAdoptable {
    var target: Constraint? { rootView.keyboardAdoptableConstraint }

    func offsetFromKeyboardWithInset(_: CGFloat) -> CGFloat {
        UIConstants.bigOffset
    }

    func updateWhileKeyboardFrameChanging(_: CGRect) {}
}
