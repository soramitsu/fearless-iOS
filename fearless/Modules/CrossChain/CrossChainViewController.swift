import UIKit
import SoraFoundation
import SnapKit

protocol CrossChainViewOutput: AnyObject {
    func didLoad(view: CrossChainViewInput)
    func didTapSelectAsset()
    func didTapSelectOriginalNetwork()
    func didTapSelectDestNetwoek()
    func updateAmount(_ newValue: Decimal)
    func selectAmountPercentage(_ percentage: Float)
    func didTapBackButton()
    func didTapConfirmButton()
}

final class CrossChainViewController: UIViewController, ViewHolder, HiddableBarWhenPushed {
    typealias RootViewType = CrossChainViewLayout
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
        rootView.originalSelectNetworkView.addAction { [weak self] in
            self?.output.didTapSelectOriginalNetwork()
        }
        rootView.destSelectNetworkView.addAction { [weak self] in
            self?.output.didTapSelectDestNetwoek()
        }
        rootView.navigationBar.backButton.addAction { [weak self] in
            self?.output.didTapBackButton()
        }
        rootView.actionButton.addAction { [weak self] in
            self?.output.didTapConfirmButton()
        }

        let locale = localizationManager?.selectedLocale ?? Locale.current
        let accessoryView = UIFactory
            .default
            .createAmountAccessoryView(for: self, locale: locale)
        rootView.amountView.textField.inputAccessoryView = accessoryView
        rootView.amountView.textField.delegate = self
        updatePreviewButton()
    }

    private func updatePreviewButton() {
        let isEnabled = amountInputViewModel?.isValid == true
        rootView.actionButton.set(enabled: isEnabled)
    }
}

// MARK: - CrossChainViewInput

extension CrossChainViewController: CrossChainViewInput {
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
    }

    func didReceive(amountInputViewModel: IAmountInputViewModel?) {
        self.amountInputViewModel = amountInputViewModel
        if let amountViewModel = amountInputViewModel {
            amountViewModel.observable.remove(observer: self)
            amountViewModel.observable.add(observer: self)
            rootView.amountView.inputFieldText = amountViewModel.displayAmount
        }
//        self.amountInputViewModel = amountInputViewModel
//        self.amountInputViewModel?.observable.remove(observer: self)
//        self.amountInputViewModel?.observable.add(observer: self)
//        rootView.amountView.inputFieldText = amountInputViewModel?.displayAmount
        updatePreviewButton()
    }

    func didReceive(originalSelectNetworkViewModel: SelectNetworkViewModel) {
        rootView.bind(originalSelectNetworkViewModel: originalSelectNetworkViewModel)
    }

    func didReceive(destSelectNetworkViewModel: SelectNetworkViewModel) {
        rootView.bind(destSelectNetworkViewModel: destSelectNetworkViewModel)
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
        let amount = amountInputViewModel?.decimalAmount ?? 0.0
        output.updateAmount(amount)
//        guard let amountTo = amountInputViewModel?.decimalAmount else {
//            return
//        }
//        output.updateAmount(amountTo)
    }
}

// MARK: - AmountInputAccessoryViewDelegate

extension CrossChainViewController: AmountInputAccessoryViewDelegate {
    func didSelect(on _: AmountInputAccessoryView, percentage: Float) {
        output.selectAmountPercentage(percentage)
    }

    func didSelectDone(on _: AmountInputAccessoryView) {
        rootView.amountView.textField.resignFirstResponder()
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
        }
        return true
    }

    func textFieldDidBeginEditing(_: UITextField) {
        rootView.amountView.set(highlighted: true, animated: false)
    }

    func textFieldDidEndEditing(_: UITextField) {
        rootView.amountView.set(highlighted: false, animated: false)
    }
}
