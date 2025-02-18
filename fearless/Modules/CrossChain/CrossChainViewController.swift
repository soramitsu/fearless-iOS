import UIKit
import SoraFoundation
import SnapKit

protocol CrossChainViewOutput: AnyObject {
    func didLoad(view: CrossChainViewInput)
    func didTapSelectAsset()
    func didTapSelectDestNetwoek()
    func updateAmount(_ newValue: Decimal)
    func selectAmountPercentage(_ percentage: Float)
    func didTapBackButton()
    func didTapContinueButton()
    func didTapScanButton()
    func didTapHistoryButton()
    func didTapMyWalletsButton()
    func didTapPasteButton()
    func searchTextDidChanged(_ text: String)
}

final class CrossChainViewController: UIViewController, ViewHolder, HiddableBarWhenPushed {
    typealias RootViewType = CrossChainViewLayout

    private enum Constants {
        static let amountInputDidChangeDelay: CGFloat = 0.5
    }

    var keyboardHandler: FearlessKeyboardHandler?

    // MARK: Private properties

    private let output: CrossChainViewOutput

    private var amountInputViewModel: IAmountInputViewModel?

    // MARK: - Constructor

    init(
        output: CrossChainViewOutput,
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
        view = CrossChainViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)
        configure()
        configureInputAccessoryView()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if keyboardHandler == nil {
            setupKeyboardHandler()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        clearKeyboardHandler()
    }

    // MARK: - Private methods

    private func configure() {
        rootView.amountView.selectHandler = { [weak self] in
            self?.output.didTapSelectAsset()
        }
        rootView.destSelectNetworkView.addAction { [weak self] in
            self?.output.didTapSelectDestNetwoek()
        }
        rootView.navigationBar.backButton.addAction { [weak self] in
            self?.output.didTapBackButton()
        }
        rootView.actionButton.addAction { [weak self] in
            self?.output.didTapContinueButton()
        }
        rootView.scanButton.addAction { [weak self] in
            self?.output.didTapScanButton()
        }
        rootView.historyButton.addAction { [weak self] in
            self?.output.didTapHistoryButton()
        }
        rootView.myWalletsButton.addAction { [weak self] in
            self?.output.didTapMyWalletsButton()
        }
        rootView.searchView.onPasteTapped = { [weak self] in
            self?.output.didTapPasteButton()
        }

        rootView.amountView.textField.delegate = self
        rootView.searchView.textField.delegate = self
        updatePreviewButton()
    }

    private func updatePreviewButton() {
        let isEnabled = amountInputViewModel?.isValid == true && rootView.searchView.textField.text.or("").isNotEmpty && (rootView.searchView.isValid != nil)
        rootView.actionButton.set(enabled: isEnabled, changeStyle: true)
    }

    private func configureInputAccessoryView() {
        let locale = localizationManager?.selectedLocale ?? Locale.current
        let frame = CGRect(
            x: 0.0,
            y: 0.0,
            width: UIScreen.main.bounds.width,
            height: UIConstants.accessoryBarHeight
        )

        let toolBar = AmountInputAccessoryView(frame: frame)
        toolBar.actionDelegate = self
        let actions: [ViewSelectorAction] = [
            ViewSelectorAction(title: "75%", selector: #selector(toolBar.actionSelect75)),
            ViewSelectorAction(title: "50%", selector: #selector(toolBar.actionSelect50)),
            ViewSelectorAction(title: "25%", selector: #selector(toolBar.actionSelect25))
        ]

        let doneTitle = R.string.localizable.commonDone(preferredLanguages: locale.rLanguages)
        let doneAction = ViewSelectorAction(
            title: doneTitle,
            selector: #selector(toolBar.actionSelectDone)
        )

        let accessoryView = UIFactory
            .default
            .createActionsAccessoryView(
                for: actions,
                doneAction: doneAction,
                target: self,
                spacing: UIConstants.accessoryItemsSpacing,
                toolBar: toolBar
            )
        rootView.amountView.textField.inputAccessoryView = accessoryView
    }
}

// MARK: - CrossChainViewInput

extension CrossChainViewController: CrossChainViewInput {
    func setButtonLoadingState(isLoading: Bool) {
        rootView.actionButton.set(loading: isLoading)
        updatePreviewButton()
    }

    func didReceive(originFeeViewModel: LocalizableResource<BalanceViewModelProtocol>?) {
        rootView.bind(originFeeViewModel: originFeeViewModel?.value(for: selectedLocale))
    }

    func didReceive(destinationFeeViewModel: LocalizableResource<BalanceViewModelProtocol>?) {
        rootView.bind(destinationFeeViewModel: destinationFeeViewModel?.value(for: selectedLocale))
    }

    func didReceive(assetBalanceViewModel: AssetBalanceViewModelProtocol?) {
        if let assetViewModel = assetBalanceViewModel {
            rootView.bind(assetViewModel: assetViewModel)
        }
        updatePreviewButton()
    }

    func didReceive(amountInputViewModel: IAmountInputViewModel?) {
        self.amountInputViewModel = amountInputViewModel
        if let amountViewModel = amountInputViewModel {
            amountViewModel.observable.remove(observer: self)
            amountViewModel.observable.add(observer: self)
            rootView.amountView.inputFieldText = amountViewModel.displayAmount
        }
        updatePreviewButton()
    }

    func didReceive(originSelectNetworkViewModel: SelectNetworkViewModel) {
        rootView.bind(originalSelectNetworkViewModel: originSelectNetworkViewModel)
    }

    func didReceive(destSelectNetworkViewModel: SelectNetworkViewModel?) {
        rootView.bind(destSelectNetworkViewModel: destSelectNetworkViewModel)
    }

    func didReceive(recipientViewModel: RecipientViewModel) {
        rootView.bind(recipientViewModel: recipientViewModel)
        updatePreviewButton()
    }
}

// MARK: - Localizable

extension CrossChainViewController: Localizable {
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}

// MARK: - KeyboardViewAdoptable

extension CrossChainViewController: KeyboardViewAdoptable {
    var target: Constraint? { rootView.keyboardAdoptableConstraint }

    func offsetFromKeyboardWithInset(_: CGFloat) -> CGFloat { UIConstants.bigOffset }
    func updateWhileKeyboardFrameChanging(_: CGRect) {}
}

// MARK: - AmountInputViewModelObserver

extension CrossChainViewController: AmountInputViewModelObserver {
    func amountInputDidChange() {
        rootView.amountView.inputFieldText = amountInputViewModel?.displayAmount

        NSObject.cancelPreviousPerformRequests(
            withTarget: self,
            selector: #selector(updateAmounts),
            object: nil
        )
        perform(#selector(updateAmounts), with: nil, afterDelay: Constants.amountInputDidChangeDelay)
    }

    @objc private func updateAmounts() {
        guard let amount = amountInputViewModel?.decimalAmount else {
            return
        }
        output.updateAmount(amount)
    }
}

// MARK: - AmountInputAccessoryViewDelegate

extension CrossChainViewController: AmountInputAccessoryViewDelegate {
    func didSelect(on _: AmountInputAccessoryView, percentage: Float) {
        output.selectAmountPercentage(percentage)
    }

    func didSelectDone(on _: AmountInputAccessoryView) {
        rootView.amountView.textField.resignFirstResponder()
        rootView.searchView.textField.resignFirstResponder()
    }
}

// MARK: - UITextFieldDelegate

extension CrossChainViewController: UITextFieldDelegate {
    func textField(
        _ textField: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        if textField == rootView.amountView.textField {
            return amountInputViewModel?.didReceiveReplacement(string, for: range) ?? false
        } else if textField == rootView.searchView.textField {
            if range.length == 1, string.isEmpty {
                output.searchTextDidChanged("")
            } else {
                return false
            }
        }
        return true
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        let amountIsFirstResponder = textField == rootView.amountView.textField
        rootView.amountView.set(highlighted: amountIsFirstResponder, animated: false)
        let searchIsFirstResponder = textField == rootView.searchView.textField
        rootView.searchView.set(highlighted: searchIsFirstResponder, animated: false)
    }

    func textFieldDidEndEditing(_: UITextField) {
        rootView.amountView.set(highlighted: false, animated: false)
        rootView.searchView.set(highlighted: false, animated: false)
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
}
