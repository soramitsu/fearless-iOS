import UIKit

final class NewAmountInputView: UIView {
    enum LayoutConstants {
        static let iconSize: CGFloat = 32
        static let offset: CGFloat = 12
    }

    private(set) var triangularedBackgroundView: TriangularedView = {
        let view = TriangularedView()
        view.isUserInteractionEnabled = true

        view.fillColor = R.color.colorSemiBlack()!
        view.highlightedFillColor = R.color.colorSemiBlack()!

        view.strokeColor = R.color.colorWhite8()!
        view.highlightedStrokeColor = R.color.colorWhite8()!
        view.strokeWidth = 1.0
        view.layer.shadowOpacity = 0

        return view
    }()

    private(set) var iconView = UIImageView()

    private(set) var titleLabel: UILabel = {
        let label = UILabel()
        label.font = .h5Title
        label.textColor = R.color.colorStrokeGray()
        label.numberOfLines = 1
        return label
    }()

    private(set) var priceLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = R.color.colorStrokeGray()
        label.numberOfLines = 1
        return label
    }()

    private(set) var balanceLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = R.color.colorStrokeGray()
        label.numberOfLines = 1
        return label
    }()

    private(set) var symbolLabel: UILabel = {
        let label = UILabel()
        label.font = .h3Title
        label.textColor = UIColor.white
        label.numberOfLines = 1
        return label
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
            balanceLabel.text = R.string.localizable.commonAvailableFormat(
                balance,
                preferredLanguages: locale.rLanguages
            )
        } else {
            balanceLabel.text = nil
        }

        let symbol = viewModel.symbol.uppercased()
        symbolLabel.text = symbol

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
            make.top.equalTo(priceLabel.snp.bottom).offset(UIConstants.minimalOffset)
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

extension NewAmountInputView {
    var fillColor: UIColor {
        get {
            triangularedBackgroundView.fillColor
        }

        set {
            triangularedBackgroundView.fillColor = newValue
            triangularedBackgroundView.highlightedFillColor = newValue
        }
    }

    var strokeColor: UIColor {
        get {
            triangularedBackgroundView.strokeColor
        }

        set {
            triangularedBackgroundView.strokeColor = newValue
            triangularedBackgroundView.highlightedStrokeColor = newValue
        }
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

    var titleColor: UIColor? {
        get {
            titleLabel.textColor
        }

        set {
            titleLabel.textColor = newValue
        }
    }

    private var _titleFontName: String? {
        get {
            titleLabel.font.fontName
        }

        set(newValue) {
            guard let fontName = newValue else {
                titleLabel.font = nil
                return
            }

            let pointSize = titleLabel.font.pointSize

            titleLabel.font = UIFont(name: fontName, size: pointSize)

            setNeedsLayout()
        }
    }

    private var _titleFontSize: CGFloat {
        get {
            titleLabel.font.pointSize
        }

        set(newValue) {
            let fontName = titleLabel.font.fontName

            titleLabel.font = UIFont(name: fontName, size: newValue)

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

    private var _priceFontName: String? {
        get {
            priceLabel.font.fontName
        }

        set(newValue) {
            guard let fontName = newValue else {
                priceLabel.font = nil
                return
            }

            let pointSize = priceLabel.font.pointSize

            priceLabel.font = UIFont(name: fontName, size: pointSize)

            setNeedsLayout()
        }
    }

    private var _priceFontSize: CGFloat {
        get {
            priceLabel.font.pointSize
        }

        set(newValue) {
            let fontName = priceLabel.font.fontName

            priceLabel.font = UIFont(name: fontName, size: newValue)

            setNeedsLayout()
        }
    }

    var priceColor: UIColor? {
        get {
            priceLabel.textColor
        }

        set {
            priceLabel.textColor = newValue
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

    private var _balanceFontName: String? {
        get {
            balanceLabel.font.fontName
        }

        set(newValue) {
            guard let fontName = newValue else {
                balanceLabel.font = nil
                return
            }

            let pointSize = balanceLabel.font.pointSize

            balanceLabel.font = UIFont(name: fontName, size: pointSize)

            setNeedsLayout()
        }
    }

    private var _balanceFontSize: CGFloat {
        get {
            balanceLabel.font.pointSize
        }

        set(newValue) {
            let fontName = balanceLabel.font.fontName

            balanceLabel.font = UIFont(name: fontName, size: newValue)

            setNeedsLayout()
        }
    }

    var balanceColor: UIColor? {
        get {
            balanceLabel.textColor
        }

        set {
            balanceLabel.textColor = newValue
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

    private var _symbolFontName: String? {
        get {
            symbolLabel.font.fontName
        }

        set(newValue) {
            guard let fontName = newValue else {
                symbolLabel.font = nil
                return
            }

            let pointSize = symbolLabel.font.pointSize

            symbolLabel.font = UIFont(name: fontName, size: pointSize)

            setNeedsLayout()
        }
    }

    private var _symbolFontSize: CGFloat {
        get {
            symbolLabel.font.pointSize
        }

        set(newValue) {
            let fontName = symbolLabel.font.fontName

            symbolLabel.font = UIFont(name: fontName, size: newValue)

            setNeedsLayout()
        }
    }

    var symbolColor: UIColor? {
        get {
            symbolLabel.textColor
        }

        set {
            symbolLabel.textColor = newValue
        }
    }

    var fieldText: String? {
        get {
            textField.text
        }

        set {
            textField.text = newValue
            setNeedsLayout()
        }
    }

    private var _filedFontName: String? {
        get {
            textField.font?.fontName
        }

        set(newValue) {
            guard let fontName = newValue else {
                textField.font = nil
                return
            }

            let pointSize = textField.font?.pointSize ?? UIFont.labelFontSize

            textField.font = UIFont(name: fontName, size: pointSize)

            setNeedsLayout()
        }
    }

    private var _fieldFontSize: CGFloat {
        get {
            textField.font?.pointSize ?? 0.0
        }

        set(newValue) {
            let fontName = textField.font?.fontName ??
                UIFont.systemFont(ofSize: UIFont.labelFontSize).fontName

            textField.font = UIFont(name: fontName, size: newValue)

            setNeedsLayout()
        }
    }

    var fieldColor: UIColor? {
        get {
            textField.textColor
        }

        set {
            textField.textColor = newValue
        }
    }

    var assetIcon: UIImage? {
        get {
            iconView.image
        }

        set {
            iconView.image = newValue
        }
    }

    var borderWidth: CGFloat {
        get {
            triangularedBackgroundView.strokeWidth
        }

        set {
            triangularedBackgroundView.strokeWidth = newValue
        }
    }

    private var _inputIndicatorColor: UIColor {
        get {
            textField.tintColor
        }

        set {
            textField.tintColor = newValue
        }
    }
}
