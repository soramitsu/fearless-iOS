import UIKit

final class SelectableAmountInputView: UIView {
    enum LayoutConstants {
        static let iconSize: CGFloat = 28
        static let offset: CGFloat = 12
    }

    private let triangularedBackgroundView: TriangularedView = {
        let view = TriangularedView()
        view.isUserInteractionEnabled = true

        view.fillColor = R.color.colorSemiBlack()!
        view.highlightedFillColor = R.color.colorSemiBlack()!

        view.strokeColor = R.color.colorWhite8()!
        view.highlightedStrokeColor = R.color.colorWhite8()!
        view.strokeWidth = 0.5
        view.layer.shadowOpacity = 0

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
        label.textColor = UIColor.white
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
        textField.textColor = UIColor.white
        textField.font = .h2Title
        textField.returnKeyType = .done
        textField.attributedPlaceholder = NSAttributedString(
            string: "0",
            attributes: [
                .foregroundColor: R.color.colorWhite()!.withAlphaComponent(0.5),
                .font: UIFont.h2Title
            ]
        )
        textField.tintColor = .white
        textField.textAlignment = .right
        textField.keyboardType = .decimalPad
        return textField
    }()

    private let symbolStackView: UIStackView = {
        let view = UIStackView()
        view.axis = .horizontal
        view.spacing = UIConstants.minimalOffset
        return view
    }()

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

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
        setupLayout()
        applyLocalization()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Public methods

    func bind(viewModel: AssetBalanceViewModelProtocol) {
        iconView.isHidden = (viewModel.iconViewModel == nil)
        viewModel.iconViewModel?.cancel(on: iconView)
        iconView.image = nil

        priceLabel.text = viewModel.price

        if let balance = viewModel.balance {
            balanceLabel.text = R.string.localizable.commonBalanceFormat(
                balance,
                preferredLanguages: locale.rLanguages
            )
        } else {
            balanceLabel.text = nil
        }

        let symbol = viewModel.symbol.uppercased()
        symbolLabel.text = viewModel.symbol.uppercased()

        viewModel.iconViewModel?.loadAmountInputIcon(on: iconView, animated: true)
    }

    // MARK: - Private methods

    private func configure() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTapGesture))
        addGestureRecognizer(tapGesture)

        selectButton.addTarget(self, action: #selector(handleSelect), for: .touchUpInside)
    }

    private func applyLocalization() {
        titleLabel.text = R.string.localizable
            .walletSendAmountTitle(preferredLanguages: locale.rLanguages)
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
}
