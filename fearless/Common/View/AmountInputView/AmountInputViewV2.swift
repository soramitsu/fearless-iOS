import UIKit

enum AmountInputViewV2Type {
    case balance
    case available
    case bonded
}

final class AmountInputViewV2: UIView {
    enum LayoutConstants {
        static let iconSize: CGFloat = 28
        static let offset: CGFloat = 12
    }

    let type: AmountInputViewV2Type

    private let triangularedBackgroundView: TriangularedView = {
        let view = TriangularedView()
        view.isUserInteractionEnabled = true

        view.fillColor = R.color.colorSemiBlack()!
        view.highlightedFillColor = R.color.colorSemiBlack()!
        view.shadowOpacity = 0.0
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
        label.textColor = R.color.colorWhite()
        label.numberOfLines = 1
        return label
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
                .foregroundColor: R.color.colorWhite()!.withAlphaComponent(0.5),
                .font: UIFont.h2Title
            ]
        )
        textField.tintColor = R.color.colorWhite()
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

    var locale: Locale = .current {
        didSet {
            applyLocalization()
        }
    }

    // MARK: - Constructor

    init(type: AmountInputViewV2Type = .balance) {
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

    func set(highlighted: Bool, animated: Bool) {
        triangularedBackgroundView.set(highlighted: highlighted, animated: animated)
    }

    func bind(viewModel: AssetBalanceViewModelProtocol) {
        iconView.isHidden = (viewModel.iconViewModel == nil)
        viewModel.iconViewModel?.cancel(on: iconView)
        iconView.image = nil

        priceLabel.text = viewModel.price

        if let balance = viewModel.balance {
            switch type {
            case .balance:
                balanceLabel.text = R.string.localizable.commonBalanceFormat(
                    balance,
                    preferredLanguages: locale.rLanguages
                )
            case .available:
                balanceLabel.text = R.string.localizable.commonAvailableFormat(
                    balance,
                    preferredLanguages: locale.rLanguages
                )
            case .bonded:
                balanceLabel.text = R.string.localizable.stakingBondedFormat(
                    balance,
                    preferredLanguages: locale.rLanguages
                )
            }
        } else {
            balanceLabel.text = nil
        }

        let symbol = viewModel.symbol.uppercased()
        symbolLabel.text = symbol.uppercased()

        viewModel.iconViewModel?.loadAmountInputIcon(on: iconView, animated: true)
    }

    // MARK: - Private methods

    private func configure() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTapGesture))
        addGestureRecognizer(tapGesture)
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
        symbolStackView.addArrangedSubview(iconView)
        symbolStackView.addArrangedSubview(symbolLabel)
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
}

extension AmountInputViewV2 {
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
