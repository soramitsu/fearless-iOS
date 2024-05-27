import UIKit

final class OnboardingStartViewLayout: UIView {
    private let mediaView: UniversalMediaView = {
        let mediaView = UniversalMediaView(frame: .zero)
        mediaView.allowLooping = true
        mediaView.shouldHidePlayButton = true
        mediaView.shouldAutoPlayAfterPresentation = true
        mediaView.backgroundColor = .clear
        mediaView.setGIFImage(name: "animatedIcon")
        return mediaView
    }()

    private let label: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.font = R.font.soraRc0040417Bold(size: 38)
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

    private func setupLayout() {
        stackView.addArrangedSubview(mediaView)
        stackView.addArrangedSubview(label)

        addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(35)
            make.centerY.equalToSuperview().offset(-(UIConstants.bigOffset + UIConstants.actionHeight))
        }

        addSubview(startButton)
        startButton.snp.makeConstraints { make in
            make.height.equalTo(UIConstants.actionHeight)
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.bigOffset)
        }
    }

    private func applyLocalization() {
        startButton.imageWithTitleView?.title = R.string.localizable.commonStart(preferredLanguages: locale.rLanguages)
    }
}
