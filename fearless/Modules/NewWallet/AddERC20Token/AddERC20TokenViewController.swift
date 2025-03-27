import UIKit
import SoraUI
import SoraFoundation

final class AddERC20TokenViewController: UIViewController {
    
    // MARK: - Private properties

    private var output: AddERC20TokenViewOutput?
    private var viewModel: AddERC20TokenViewModel?

    private let selectNetworkView = UIFactory.default.createNetworkView(selectable: true)

    private let tokenAddressField: CommonInputView = {
        let field = CommonInputView()
        field.animatedInputField.textField.autocapitalizationType = .none
        field.animatedInputField.textField.autocorrectionType = .no
        field.animatedInputField.textField.keyboardType = .asciiCapable
        field.animatedInputField.textField.returnKeyType = .send
        return field
    }()

    private let tokenNameField: CommonInputView = {
        let field = CommonInputView()
        field.animatedInputField.isEnabled = false
        return field
    }()

    private let tokenSymbolField: CommonInputView = {
        let field = CommonInputView()
        field.animatedInputField.isEnabled = false
        return field
    }()

    private let tokenDecimalsField: CommonInputView = {
        let field = CommonInputView()
        field.animatedInputField.isEnabled = false
        return field
    }()

    private let tokenTotalSupplyField: CommonInputView = {
        let field = CommonInputView()
        field.animatedInputField.isEnabled = false
        return field
    }()

    private let saveButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyEnabledStyle()
        return button
    }()

    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        return stack
    }()

    private let scrollView: UIScrollView = {
        let scroll = UIScrollView()
        scroll.keyboardDismissMode = .interactive
        return scroll
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupLayout()
        setupActions()
        
        tokenAddressField.animatedInputField.delegate = self
        
        output?.didLoad(view: self)
    }

    // MARK: - Constructor

    init(
        output: AddERC20TokenViewOutput,
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

    // MARK: - Private methods

    private func setupLayout() {
        view.backgroundColor = R.color.colorBlack()

        view.addSubview(scrollView)
        scrollView.addSubview(stackView)

        stackView.addArrangedSubview(selectNetworkView)
        selectNetworkView.snp.makeConstraints { make in
            make.height.equalTo(48)
        }

        [tokenAddressField, tokenNameField, tokenSymbolField, tokenDecimalsField, tokenTotalSupplyField].forEach { field in
            field.isHidden = true
            stackView.addArrangedSubview(field)
            field.snp.makeConstraints { make in
                make.height.equalTo(52)
            }
        }

        stackView.addArrangedSubview(saveButton)
        saveButton.snp.makeConstraints { make in
            make.height.equalTo(48)
        }

        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalToSuperview()
            make.height.equalToSuperview().priority(.low)
        }
    }

    private func setupActions() {
        selectNetworkView.addAction { [weak self] in
            self?.output?.didTapSelectNetwork()
        }

        tokenAddressField.animatedInputField.addTarget(
            self,
            action: #selector(tokenAddressChanged),
            for: .editingChanged
        )

        saveButton.addTarget(
            self,
            action: #selector(saveButtonTapped),
            for: .touchUpInside
        )
    }

    @objc private func tokenAddressChanged() {
        output?.didChangeTokenAddress(tokenAddressField.animatedInputField.text ?? "")
    }

    @objc private func saveButtonTapped() {
        output?.didTapSave()
    }
}

// MARK: - AddERC20TokenViewInput

extension AddERC20TokenViewController: AddERC20TokenViewInput {
    func didReceive(viewModel: AddERC20TokenViewModel) {
        self.viewModel = viewModel

        tokenNameField.isHidden = viewModel.tokenName == nil
        tokenSymbolField.isHidden = viewModel.tokenSymbol == nil
        tokenDecimalsField.isHidden = viewModel.tokenDecimals == nil
        tokenTotalSupplyField.isHidden = viewModel.tokenTotalSupply == nil
        
        tokenNameField.animatedInputField.text = viewModel.tokenName
        tokenSymbolField.animatedInputField.text = viewModel.tokenSymbol
        tokenDecimalsField.animatedInputField.text = viewModel.tokenDecimals.map { String($0) }
        tokenTotalSupplyField.animatedInputField.text = viewModel.tokenTotalSupply.map { String($0) }

        saveButton.set(enabled: viewModel.isSaveEnabled, changeStyle: true)
    }

    func didReceive(isLoading: Bool) {
        saveButton.set(loading: isLoading)
    }

    func didReceive(selectNetworkViewModel: SelectNetworkViewModel?) {
        tokenAddressField.isHidden = selectNetworkViewModel == nil
        
        guard let selectNetworkViewModel else {
            selectNetworkView.subtitle = R.string.localizable.commonSelectNetwork(preferredLanguages: selectedLocale.rLanguages)
            selectNetworkView.iconView.image = R.image.addressPlaceholder()
            return
        }
        selectNetworkView.subtitle = selectNetworkViewModel.chainName
        selectNetworkViewModel.iconViewModel?.cancel(on: selectNetworkView.iconView)
        selectNetworkView.iconView.image = nil
        selectNetworkViewModel
            .iconViewModel?
            .loadAmountInputIcon(on: selectNetworkView.iconView, animated: true)
    }
}

extension AddERC20TokenViewController: Localizable {
    func applyLocalization() {
        title = R.string.localizable.addTokenTitle(preferredLanguages: selectedLocale.rLanguages)
        selectNetworkView.title = R.string.localizable.commonSelectNetwork(preferredLanguages: selectedLocale.rLanguages)
        tokenAddressField.title = R.string.localizable.addTokenAddressTitle(preferredLanguages: selectedLocale.rLanguages)
        tokenNameField.title = R.string.localizable.addTokenNameTitle(preferredLanguages: selectedLocale.rLanguages)
        tokenSymbolField.title = R.string.localizable.addTokenSymbolTitle(preferredLanguages: selectedLocale.rLanguages)
        tokenDecimalsField.title = R.string.localizable.addTokenDecimalsTitle(preferredLanguages: selectedLocale.rLanguages)
        tokenTotalSupplyField.title = R.string.localizable.addTokenTotalSupplyTitle(preferredLanguages: selectedLocale.rLanguages)
        saveButton.imageWithTitleView?.title = R.string.localizable.commonSave(preferredLanguages: selectedLocale.rLanguages)
    }
}

extension AddERC20TokenViewController: AnimatedTextFieldDelegate {
    func animatedTextFieldShouldReturn(_ textField: AnimatedTextField) -> Bool {
        if textField === tokenAddressField.animatedInputField {
            output?.didChangeTokenAddress(textField.text ?? "")
        }
        
        textField.resignFirstResponder()
        return false
    }

    func animatedTextField(
        _ textField: AnimatedTextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        if textField === tokenAddressField.animatedInputField {
            output?.didChangeTokenAddress(string)
        }
        return true
    }
}
