import UIKit
import Kingfisher

enum SelectableAmountInputViewType {
    case send
    case swapSend
    case swapReceive
}

final class SelectableAmountInputView: UIView {
    enum LayoutConstants {
        static let iconSize: CGFloat = 28
        static let offset: CGFloat = 12
    }

    private let type: SelectableAmountInputViewType
    private var sendPresentation = false
    private var displayedBalance: String?

    private let amountReadoutLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.numberOfLines = 0
        label.lineBreakMode = .byCharWrapping
        label.textAlignment = .right
        label.isAccessibilityElement = false
        label.isUserInteractionEnabled = false
        label.isHidden = true
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        return label
    }()

    private let triangularedBackgroundView: TriangularedView = {
        let view = TriangularedView()
        view.isUserInteractionEnabled = true

        view.fillColor = R.color.colorSemiBlack()!
        view.highlightedFillColor = R.color.colorSemiBlack()!

        view.strokeColor = R.color.colorWhite8()!
        view.highlightedStrokeColor = R.color.colorPink()!
        view.strokeWidth = 0.5
        view.shadowOpacity = 0

        return view
    }()

    private(set) var iconView = UIImageView()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .h5Title
        label.textColor = R.color.colorStrokeGray()
        label.numberOfLines = 1
        return label
    }()

    private let priceLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = R.color.colorStrokeGray()
        label.numberOfLines = 1
        return label
    }()

    private let balanceLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = R.color.colorStrokeGray()
        label.numberOfLines = 1
        return label
    }()

    private let symbolLabel: UILabel = {
        let label = UILabel()
        label.font = .h3Title
        label.textColor = R.color.colorWhite()
        label.numberOfLines = 1
        return label
    }()

    private let iconSelect: UIImageView = {
        let view = UIImageView()
        view.contentMode = .center
        view.image = R.image.dropTriangle()
        return view
    }()

    private(set) var textField: UITextField = {
        let textField = UITextField()
        textField.borderStyle = .none
        textField.textColor = R.color.colorWhite()
        textField.font = .h2Title
        textField.returnKeyType = .done
        textField.attributedPlaceholder = NSAttributedString(
            string: "0",
            attributes: [
                .foregroundColor: R.color.colorWhite()!,
                .font: UIFont.h2Title
            ]
        )
        textField.tintColor = R.color.colorWhite()
        textField.textAlignment = .right
        textField.keyboardType = .decimalPad
        return textField
    }()

    private let symbolStackView = UIFactory.default.createHorizontalStackView(
        spacing: UIConstants.minimalOffset
    )

    private let selectButton: UIButton = {
        let button = UIButton()
        button.backgroundColor = .clear
        return button
    }()

    var selectHandler: (() -> Void)?

    var locale: Locale = .current {
        didSet {
            applyLocalization()
        }
    }

    // MARK: - Constructor

    init(type: SelectableAmountInputViewType) {
        self.type = type
        super.init(frame: .zero)
        configure()
        setupLayout()
        applyLocalization()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Public methods

    func bind(viewModel: AssetBalanceViewModelProtocol?) {
        displayedBalance = viewModel?.balance
        guard let viewModel = viewModel else {
            iconView.image = R.image.addressPlaceholder()
            symbolLabel.text = R.string.localizable
                .commonSelectAsset(preferredLanguages: locale.rLanguages)
            return
        }
        clearInputView()

        priceLabel.text = viewModel.price

        if let balance = viewModel.balance {
            applyType(for: balance)
        } else {
            balanceLabel.text = nil
        }

        symbolLabel.text = viewModel.symbol.uppercased()

        viewModel.iconViewModel?.loadAmountInputIcon(on: iconView, animated: true)
        iconSelect.isHidden = !viewModel.selectable
    }

    // MARK: - Private methods

    private func clearInputView() {
        iconView.image = nil
        iconView.kf.cancelDownloadTask()
    }

    private func applyType(for balance: String) {
        switch type {
        case .send, .swapSend, .swapReceive:
            balanceLabel.text = R.string.localizable.commonAvailableFormat(
                balance,
                preferredLanguages: locale.rLanguages
            )
        }
    }

    private func applyLocalization() {
        if sendPresentation, let displayedBalance { applyType(for: displayedBalance) }
        switch type {
        case .send:
            titleLabel.text = R.string.localizable
                .walletSendAmountTitle(preferredLanguages: locale.rLanguages)
        case .swapSend:
            titleLabel.text = R.string.localizable
                .walletSendTitle(preferredLanguages: locale.rLanguages)
        case .swapReceive:
            titleLabel.text = R.string.localizable
                .commonActionReceive(preferredLanguages: locale.rLanguages)
        }
    }

    @objc private func updateAmountPresentation() {
        guard sendPresentation else { return }
        let editing = textField.isFirstResponder
        // Keep the same native editor, delegate, cursor and accessibility value. Outside editing,
        // a full-size multiline readout supplies the space a single-line field cannot reserve.
        amountReadoutLabel.text = editing ? nil : (textField.text?.isEmpty == false ? textField.text : "0")
        amountReadoutLabel.isHidden = editing
        textField.textColor = editing ? R.color.colorWhite() : .clear
        textField.attributedPlaceholder = NSAttributedString(string: "0", attributes: [
            .foregroundColor: editing ? R.color.colorWhite()! : UIColor.clear, .font: textField.font!
        ])
        setNeedsLayout()
    }

    private func configure() {
        textField.addTarget(
            self,
            action: #selector(updateAmountPresentation),
            for: [.editingDidBegin, .editingChanged, .editingDidEnd]
        )
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTapGesture))
        addGestureRecognizer(tapGesture)

        selectButton.addTarget(self, action: #selector(handleSelect), for: .touchUpInside)
    }

    private func setupLayout() {
        addSubview(triangularedBackgroundView)
        addSubview(titleLabel)
        addSubview(priceLabel)
        addSubview(symbolStackView)
        addSubview(selectButton)
        symbolStackView.addArrangedSubview(iconView)
        symbolStackView.addArrangedSubview(symbolLabel)
        symbolStackView.addArrangedSubview(iconSelect)
        addSubview(textField)
        addSubview(amountReadoutLabel)
        addSubview(balanceLabel)

        symbolLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        triangularedBackgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        titleLabel.snp.makeConstraints { make in
            make.leading.top.equalToSuperview().offset(LayoutConstants.offset)
        }

        priceLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(LayoutConstants.offset)
            make.trailing.equalToSuperview().offset(-LayoutConstants.offset)
        }

        symbolStackView.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel.snp.leading)
            make.top.equalTo(titleLabel.snp.bottom).offset(UIConstants.minimalOffset)
        }

        selectButton.snp.makeConstraints { make in
            make.edges.equalTo(symbolStackView)
        }

        iconView.snp.makeConstraints { make in
            make.size.equalTo(LayoutConstants.iconSize)
        }

        textField.snp.makeConstraints { make in
            make.trailing.equalTo(priceLabel)
            make.centerY.equalTo(symbolStackView)
            make.leading.equalTo(symbolStackView.snp.trailing).offset(UIConstants.bigOffset)
        }

        balanceLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.top.equalTo(symbolStackView.snp.bottom).offset(UIConstants.minimalOffset)
            make.bottom.equalToSuperview().offset(-LayoutConstants.offset)
        }
    }

    @objc private func handleTapGesture() {
        if !textField.isFirstResponder {
            textField.becomeFirstResponder()
        }
    }

    @objc private func handleSelect() {
        selectHandler?()
    }
}

extension SelectableAmountInputView {
    /// Preserve the editor and its delegates while allowing the Send card to grow.
    func configureSendPresentation(locale: Locale, traits: UITraitCollection) {
        sendPresentation = true
        self.locale = locale
        titleLabel.font = .fw(.bodyS, locale: locale, compatibleWith: traits)
        priceLabel.font = .fw(.numberM, locale: locale, compatibleWith: traits)
        balanceLabel.font = .fw(.bodyM, locale: locale, compatibleWith: traits)
        symbolLabel.font = .fw(.titleS, locale: locale, compatibleWith: traits)
        textField.font = .fw(.displayL, locale: locale, compatibleWith: traits)
        amountReadoutLabel.font = textField.font
        textField.attributedPlaceholder = NSAttributedString(string: "0", attributes: [
            .foregroundColor: R.color.colorWhite()!, .font: textField.font!
        ])
        [titleLabel, priceLabel, balanceLabel, symbolLabel].forEach {
            $0.numberOfLines = 0
            $0.lineBreakMode = .byCharWrapping
            $0.setContentCompressionResistancePriority(.required, for: .vertical)
        }
        titleLabel.snp.remakeConstraints { $0.leading.trailing.top.equalToSuperview().inset(12) }
        priceLabel.snp.remakeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(12)
            make.top.equalTo(titleLabel.snp.bottom).offset(6)
        }
        symbolStackView.alignment = .center
        symbolStackView.snp.remakeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(12)
            make.top.equalTo(priceLabel.snp.bottom).offset(8)
            make.height.greaterThanOrEqualTo(44)
        }
        iconSelect.snp.remakeConstraints { $0.size.equalTo(16) }
        textField.snp.remakeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(12)
            make.top.equalTo(symbolStackView.snp.bottom).offset(8)
            make.height.greaterThanOrEqualTo(ceil(textField.font!.lineHeight) + 12)
        }
        amountReadoutLabel.snp.remakeConstraints { make in
            make.leading.trailing.equalTo(textField)
            make.top.equalTo(textField).offset(6)
            make.bottom.equalTo(textField).offset(-6)
        }
        balanceLabel.snp.remakeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview().inset(12)
            make.top.equalTo(textField.snp.bottom).offset(8)
        }
        updateAmountPresentation()
        setNeedsLayout()
    }

    var title: String? {
        get {
            titleLabel.text
        }

        set {
            titleLabel.text = newValue
            setNeedsLayout()
        }
    }

    var priceText: String? {
        get {
            priceLabel.text
        }

        set {
            priceLabel.text = newValue
            setNeedsLayout()
        }
    }

    var balanceText: String? {
        get {
            balanceLabel.text
        }

        set {
            balanceLabel.text = newValue
            setNeedsLayout()
        }
    }

    var symbol: String? {
        get {
            symbolLabel.text
        }

        set {
            symbolLabel.text = newValue
            setNeedsLayout()
        }
    }

    var inputFieldText: String? {
        get {
            textField.text
        }

        set {
            if textField.text != newValue { textField.text = newValue }
            updateAmountPresentation()
            setNeedsLayout()
        }
    }

    func set(highlighted: Bool, animated: Bool) {
        triangularedBackgroundView.set(highlighted: highlighted, animated: animated)
    }
}
