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
        guard let viewModel = viewModel else {
            iconView.image = R.image.addressPlaceholder()
            symbolLabel.text = R.string.localizable
                .commonSelectAsset(preferredLanguages: locale.rLanguages)
            return
        }
        clearInputView()

        priceLabel.text = viewModel.price

        if var balance = viewModel.balance {
            applyType(for: balance)
        } else {
            balanceLabel.text = nil
        }

        symbolLabel.text = viewModel.symbol.uppercased()

        viewModel.iconViewModel?.loadAmountInputIcon(on: iconView, animated: true)
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
        switch type {
        case .send:
            titleLabel.text = R.string.localizable
                .walletSendAmountTitle(preferredLanguages: locale.rLanguages)
        case .swapSend:
            titleLabel.text = R.string.localizable
                .walletSendTitle(preferredLanguages: locale.rLanguages)
        case .swapReceive:
            titleLabel.text = R.string.localizable
                .walletAssetReceive(preferredLanguages: locale.rLanguages)
        }
    }

    private func configure() {
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
            textField.text = newValue
            setNeedsLayout()
        }
    }

    func set(highlighted: Bool, animated: Bool) {
        triangularedBackgroundView.set(highlighted: highlighted, animated: animated)
    }
}
