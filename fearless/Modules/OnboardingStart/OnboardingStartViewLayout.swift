import UIKit

final class OnboardingStartViewLayout: UIView {
    /// The stacked lockup whose crest lights the page (Yatagarasu brand; the welcome screen carries the crow).
    private let mediaView = FWLockupView()

    private let sunlitBackground = FWSunlitBackgroundView()

    private let label: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.font = UIFont.legacySora(size: 38, weight: .bold)
        label.numberOfLines = 0
        label.textAlignment = .center
        return label
    }()

    private let stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = UIConstants.bigOffset
        return stackView
    }()

    let startButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyEnabledStyle()
        return button
    }()

    var locale: Locale = .current {
        didSet {
            applyLocalization()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Private methods

    private func configure() {
        let fullString = "The DeFi Wallet for the Future"
        let coloredSubstring = "Future"
        let range = (fullString as NSString).range(of: coloredSubstring)
        let mutableAttributedString = NSMutableAttributedString(string: fullString)
        mutableAttributedString.addAttribute(NSAttributedString.Key.foregroundColor, value: R.color.colorPink()!, range: range)
        label.attributedText = mutableAttributedString
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        sunlitBackground.sunCenter = mediaView.convert(mediaView.crestCenterPoint, to: self)
    }

    private func setupLayout() {
        backgroundColor = FWSunlit.Palette.background
        addSubview(sunlitBackground)
        sunlitBackground.snp.makeConstraints { make in make.edges.equalToSuperview() }
        let lockupRow = UIView()
        lockupRow.addSubview(mediaView)
        mediaView.snp.makeConstraints { make in
            mediaView.makePageConstraints(make)
            make.top.bottom.equalToSuperview()
        }
        stackView.addArrangedSubview(lockupRow)
        stackView.addArrangedSubview(label)

        addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.leading.trailing.equalTo(safeAreaLayoutGuide).inset(24)
            make.centerY.equalToSuperview().offset(-(UIConstants.bigOffset + UIConstants.actionHeight))
        }

        addSubview(startButton)
        startButton.snp.makeConstraints { make in
            make.height.equalTo(UIConstants.actionHeight)
            make.leading.trailing.equalTo(safeAreaLayoutGuide).inset(UIConstants.bigOffset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.bigOffset)
        }
    }

    private func applyLocalization() {
        startButton.imageWithTitleView?.title = R.string.localizable.commonStart(preferredLanguages: locale.rLanguages)
    }
}
