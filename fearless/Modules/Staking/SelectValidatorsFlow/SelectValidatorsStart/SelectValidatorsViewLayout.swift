import UIKit

final class SelectValidatorsViewLayout: UIView {
    let contentView: ScrollableContainerView = {
        let view = ScrollableContainerView()
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.layoutMargins = UIEdgeInsets(top: 8.0, left: 0.0, bottom: 0.0, right: 0.0)
        return view
    }()

    var stackView: UIStackView {
        contentView.stackView
    }

    let suggestedValidatorsBackground: TriangularedView = {
        let view = TriangularedView()
        view.fillColor = R.color.colorSemiBlack()!
        view.highlightedFillColor = R.color.colorSemiBlack()!
        view.strokeColor = R.color.colorWhite16()!
        view.highlightedStrokeColor = R.color.colorWhite16()!
        view.strokeWidth = 0.5
        view.shadowOpacity = 0.0

        return view
    }()

    let suggestedValidatorsStackView = UIFactory.default.createVerticalStackView(spacing: UIConstants.bigOffset)

    let selectedValidatorsBackground: TriangularedView = {
        let view = TriangularedView()
        view.fillColor = R.color.colorSemiBlack()!
        view.highlightedFillColor = R.color.colorSemiBlack()!
        view.strokeColor = R.color.colorWhite16()!
        view.highlightedStrokeColor = R.color.colorWhite16()!
        view.strokeWidth = 0.5
        view.shadowOpacity = 0.0

        return view
    }()

    let selectedValidatorsStackView = UIFactory.default.createVerticalStackView(spacing: UIConstants.bigOffset)

    let recommendedValidatorsButton: TriangularedButton = {
        let view = UIFactory.default.createMainActionButton()
        return view
    }()

    private(set) lazy var recommendedValidatorsActivityIndicator = createActivityIndicatorView()

    private(set) lazy var customValidatorsActivityIndicator = createActivityIndicatorView()

    let algoSectionLabel: UILabel = {
        let label = UILabel()
        label.font = .h4Title
        label.textColor = R.color.colorWhite()
        label.numberOfLines = 0
        return label
    }()

    let algoDetailsLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textColor = R.color.colorWhite()
        label.numberOfLines = 0
        return label
    }()

    private(set) var algoSteps: [IconDetailsView] = []

    let customValidatorsCell: TriangularedButton = {
        let view = UIFactory.default.createMainActionButton()
        return view
    }()

    let customValidatorsSectionLabel: UILabel = {
        let label = UILabel()
        label.font = .h4Title
        label.textColor = R.color.colorWhite()
        label.numberOfLines = 0
        return label
    }()

    let customValidatorsDetailsLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textColor = R.color.colorWhite()
        label.numberOfLines = 0
        return label
    }()

    var locale: Locale = .current {
        didSet {
            applyLocalization()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorBlack()

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setAlgoSteps(_ steps: [String]) {
        algoSteps.forEach {
            stackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        guard !steps.isEmpty else {
            return
        }

        algoSteps = steps.map { step in
            let view = IconDetailsView()
            view.imageView.image = R.image.iconAlgoItem()
            view.detailsLabel.text = step
            view.detailsLabel.textColor = R.color.colorWhite()
            return view
        }

        let prevView: UIView = algoDetailsLabel

        let lastStepView = algoSteps.reduce(prevView) { prevView, stepView in
            suggestedValidatorsStackView.insertArranged(view: stepView, after: prevView)
            return stepView
        }

        stackView.setCustomSpacing(5.0, after: lastStepView)
    }

    private func setupLayout() {
        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview()
        }

        stackView.addArrangedSubview(suggestedValidatorsBackground)
        suggestedValidatorsBackground.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
        }
        suggestedValidatorsBackground.addSubview(suggestedValidatorsStackView)
        suggestedValidatorsStackView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIConstants.horizontalInset)
        }

        suggestedValidatorsStackView.addArrangedSubview(algoSectionLabel)
        suggestedValidatorsStackView.addArrangedSubview(algoDetailsLabel)
        suggestedValidatorsStackView.addArrangedSubview(recommendedValidatorsButton)

        recommendedValidatorsButton.activityIndicator = recommendedValidatorsActivityIndicator

        stackView.setCustomSpacing(20, after: suggestedValidatorsBackground)
        stackView.addArrangedSubview(selectedValidatorsBackground)
        selectedValidatorsBackground.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
        }
        selectedValidatorsBackground.addSubview(selectedValidatorsStackView)
        selectedValidatorsStackView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIConstants.horizontalInset)
        }

        selectedValidatorsStackView.addArrangedSubview(customValidatorsSectionLabel)
        selectedValidatorsStackView.addArrangedSubview(customValidatorsDetailsLabel)
        selectedValidatorsStackView.addArrangedSubview(customValidatorsCell)

        selectedValidatorsStackView.setCustomSpacing(12.0, after: customValidatorsSectionLabel)
        selectedValidatorsStackView.setCustomSpacing(24.0, after: customValidatorsDetailsLabel)

        customValidatorsCell.activityIndicator = customValidatorsActivityIndicator
    }

    private func createActivityIndicatorView() -> UIActivityIndicatorView {
        let view = UIActivityIndicatorView()
        view.hidesWhenStopped = true
        view.isUserInteractionEnabled = false
        view.color = R.color.colorWhite()
        view.style = UIActivityIndicatorView.Style.medium
        return view
    }

    private func applyLocalization() {
        customValidatorsCell.imageWithTitleView?.title = R.string.localizable
            .stakingPoolSelectValidatorsManual(
                preferredLanguages: locale.rLanguages
            )
        recommendedValidatorsButton.imageWithTitleView?.title = R.string.localizable
            .stakingPoolSelectValidatorsSuggested(
                preferredLanguages: locale.rLanguages
            )
    }
}
