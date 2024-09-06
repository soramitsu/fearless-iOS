import UIKit
import Kingfisher

enum SelectableAmountInputViewType {
    case send
    case swapSend
    case swapReceive
}

final class SelectableAmountInputView: UIView {
    enum LayoutConstants {
        static let iconSize: CGFloat = 40
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

    // Placeholder state views

    private let placeholderView = UIView()

    private(set) var placeholderIconView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = R.image.iconTokenPlaceholder()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    private let placeholderTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .h5Title
        label.textColor = R.color.colorStrokeGray()
        label.numberOfLines = 1
        return label
    }()

    private let placeholderSymbolLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = R.color.colorStrokeGray()
        label.numberOfLines = 1
        return label
    }()

    private let placeholderSelectIcon: UIImageView = {
        let view = UIImageView()
        view.contentMode = .center
        view.image = R.image.iconDownStrokeGray()
        return view
    }()

    // Normal state views

    private let leftView: UIView = {
        let view = UIView()
        view.isHidden = true
        return view
    }()

    private(set) var iconView: UIImageView = {
        let imageView = UIImageView()
        return imageView
    }()

    private let chainLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = R.color.colorStrokeGray()
        label.numberOfLines = 1
        return label
    }()

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

    private let symbolView: UIStackView = {
        let stackView = UIFactory.default.createHorizontalStackView(spacing: 4)
        return stackView
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

    private let iconBalance: UIImageView = {
        let view = UIImageView()
        view.contentMode = .center
        view.image = R.image.iconWalletBalance()
        view.isHidden = true
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

    private let leftStackView: UIStackView = {
        let stackView = UIFactory.default.createVerticalStackView(spacing: 6)
        return stackView
    }()

    private let rightStackView: UIStackView = {
        let stackView = UIFactory.default.createVerticalStackView()
        stackView.alignment = .trailing
        return stackView
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

        leftView.isHidden = false
        placeholderView.isHidden = true

        clearInputView()

        priceLabel.text = viewModel.price

        if let balance = viewModel.balance {
            applyType(for: balance)
        } else {
            balanceLabel.text = nil
        }

        symbolLabel.text = viewModel.symbol.uppercased()
        chainLabel.text = viewModel.chain

        viewModel.iconViewModel?.loadAmountInputIcon(on: iconView, animated: true)
        iconSelect.isHidden = !viewModel.selectable
    }

    // MARK: - Private methods

    private func clearInputView() {
        iconView.image = nil
        iconView.kf.cancelDownloadTask()
    }

    private func applyType(for balance: String) {
        iconBalance.isHidden = false

        switch type {
        case .send, .swapSend, .swapReceive:
            balanceLabel.text = balance
        }
    }

    private func applyLocalization() {
        switch type {
        case .send:
            titleLabel.text = R.string.localizable
                .walletSendAmountTitle(preferredLanguages: locale.rLanguages)
            placeholderTitleLabel.text = R.string.localizable
                .walletSendAmountTitle(preferredLanguages: locale.rLanguages)
        case .swapSend:
            titleLabel.text = R.string.localizable
                .walletSendTitle(preferredLanguages: locale.rLanguages)
            placeholderTitleLabel.text = R.string.localizable
                .walletSendTitle(preferredLanguages: locale.rLanguages)
        case .swapReceive:
            titleLabel.text = R.string.localizable
                .commonActionReceive(preferredLanguages: locale.rLanguages)
            placeholderTitleLabel.text = R.string.localizable
                .commonActionReceive(preferredLanguages: locale.rLanguages)
        }

        placeholderSymbolLabel.text = R.string.localizable.commonSelectAsset(preferredLanguages: locale.rLanguages)
    }

    private func configure() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTapGesture))
        addGestureRecognizer(tapGesture)

        selectButton.addTarget(self, action: #selector(handleSelect), for: .touchUpInside)
    }

    private func setupPlaceholderSubviews() {
        leftStackView.addArrangedSubview(placeholderView)

        placeholderView.addSubview(placeholderIconView)
        placeholderView.addSubview(placeholderTitleLabel)
        placeholderView.addSubview(placeholderSymbolLabel)
        placeholderView.addSubview(placeholderSelectIcon)

        placeholderIconView.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.centerY.equalToSuperview()
        }

        placeholderTitleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.equalTo(placeholderIconView.snp.trailing).offset(8)
        }

        placeholderSymbolLabel.snp.makeConstraints { make in
            make.leading.equalTo(placeholderTitleLabel.snp.leading)
            make.top.equalTo(placeholderTitleLabel.snp.bottom).offset(8)
            make.bottom.equalToSuperview()
        }

        placeholderSelectIcon.snp.makeConstraints { make in
            make.leading.equalTo(placeholderSymbolLabel.snp.trailing).offset(6)
            make.trailing.equalToSuperview()
            make.centerY.equalTo(placeholderSymbolLabel.snp.centerY)
        }
    }

    private func setupLeftViews() {
        leftStackView.addArrangedSubview(leftView)

        leftView.addSubview(iconView)
        leftView.addSubview(titleLabel)
        leftView.addSubview(symbolLabel)
        leftView.addSubview(chainLabel)
        leftView.addSubview(iconSelect)

        titleLabel.snp.makeConstraints { make in
            make.leading.top.equalToSuperview()
        }

        iconView.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(4)
            make.leading.bottom.equalToSuperview()
            make.size.equalTo(LayoutConstants.iconSize)
        }

        symbolLabel.snp.makeConstraints { make in
            make.top.equalTo(iconView.snp.top)
            make.leading.equalTo(iconView.snp.trailing).offset(4)
            make.height.equalTo(23)
        }

        chainLabel.snp.makeConstraints { make in
            make.leading.equalTo(symbolLabel.snp.leading)
            make.top.equalTo(symbolLabel.snp.bottom)
            make.bottom.equalTo(iconView.snp.bottom)
            make.trailing.equalToSuperview()
            make.height.equalTo(17)
        }

        iconSelect.snp.makeConstraints { make in
            make.leading.equalTo(symbolLabel.snp.trailing).offset(4)
            make.centerY.equalTo(symbolLabel.snp.centerY)
            make.width.equalTo(12)
        }
    }

    private func setupLayout() {
        addSubview(triangularedBackgroundView)
        addSubview(leftStackView)
        addSubview(rightStackView)

        setupPlaceholderSubviews()
        setupLeftViews()

        rightStackView.addArrangedSubview(balanceLabel)
        rightStackView.addArrangedSubview(textField)
        rightStackView.addArrangedSubview(priceLabel)

        addSubview(selectButton)
        addSubview(iconBalance)

        iconSelect.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        titleLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        iconBalance.snp.makeConstraints { make in
            make.size.equalTo(16)
            make.trailing.equalTo(balanceLabel.snp.leading).offset(-4)
            make.centerY.equalTo(balanceLabel.snp.centerY)
        }
        textField.snp.makeConstraints { make in
            make.centerY.equalTo(self.snp.centerY)
        }

        triangularedBackgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        leftStackView.snp.makeConstraints { make in
            make.leading.top.equalToSuperview().offset(12)
            make.bottom.equalToSuperview().offset(-12)
        }

        rightStackView.snp.makeConstraints { make in
            make.trailing.top.bottom.equalToSuperview().inset(12)
            make.leading.equalTo(leftStackView.snp.trailing).offset(16)
        }

        selectButton.snp.makeConstraints { make in
            make.edges.equalTo(leftStackView)
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
