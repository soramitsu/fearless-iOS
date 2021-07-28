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

    let recommendedValidatorsCell: RowView<TitleValueSelectionView> = {
        let view = UIFactory.default.createTitleValueSelectionView()
        view.detailsLabel.textColor = R.color.colorWhite()
        view.iconView.image = R.image.iconValidators()
        return RowView(contentView: view, preferredHeight: 48.0)
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
        label.textColor = R.color.colorLightGray()
        label.numberOfLines = 0
        return label
    }()

    private(set) var algoSteps: [IconDetailsView] = []

    let customValidatorsCell: RowView<TitleValueSelectionView> = {
        let view = UIFactory.default.createTitleValueSelectionView()
        view.detailsLabel.textColor = R.color.colorWhite()
        view.iconView.image = R.image.iconList()
        return RowView(contentView: view, preferredHeight: 48.0)
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
        label.textColor = R.color.colorLightGray()
        label.numberOfLines = 0
        return label
    }()

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
            return view
        }

        let prevView: UIView = algoDetailsLabel

        let lastStepView = algoSteps.reduce(prevView) { prevView, stepView in
            stackView.insertArranged(view: stepView, after: prevView)

            stepView.snp.makeConstraints { make in
                make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
            }

            stackView.setCustomSpacing(6.0, after: stepView)

            return stepView
        }

        stackView.setCustomSpacing(8.0, after: lastStepView)
    }

    private func setupLayout() {
        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide)
            make.bottom.leading.trailing.equalToSuperview()
        }

        stackView.addArrangedSubview(algoSectionLabel)
        algoSectionLabel.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
        }

        stackView.setCustomSpacing(8.0, after: algoSectionLabel)

        stackView.addArrangedSubview(algoDetailsLabel)
        algoDetailsLabel.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
        }

        stackView.setCustomSpacing(16.0, after: algoDetailsLabel)

        stackView.addArrangedSubview(recommendedValidatorsCell)
        recommendedValidatorsCell.snp.makeConstraints { make in
            make.width.equalTo(self)
        }

        stackView.setCustomSpacing(24.0, after: recommendedValidatorsCell)

        recommendedValidatorsCell.rowContentView.addSubview(recommendedValidatorsActivityIndicator)
        recommendedValidatorsActivityIndicator.snp.makeConstraints { make in
            make.trailing.centerY.equalToSuperview()
        }

        stackView.addArrangedSubview(customValidatorsSectionLabel)
        customValidatorsSectionLabel.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
        }

        stackView.setCustomSpacing(8.0, after: customValidatorsSectionLabel)

        stackView.addArrangedSubview(customValidatorsDetailsLabel)
        customValidatorsDetailsLabel.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
        }

        stackView.setCustomSpacing(8.0, after: customValidatorsDetailsLabel)

        stackView.addArrangedSubview(customValidatorsCell)
        customValidatorsCell.snp.makeConstraints { make in
            make.width.equalTo(self)
        }

        customValidatorsCell.rowContentView.addSubview(customValidatorsActivityIndicator)
        customValidatorsActivityIndicator.snp.makeConstraints { make in
            make.trailing.centerY.equalToSuperview()
        }
    }

    private func createActivityIndicatorView() -> UIActivityIndicatorView {
        let view = UIActivityIndicatorView()
        view.hidesWhenStopped = true
        view.isUserInteractionEnabled = false
        view.color = R.color.colorWhite()
        view.style = .white
        return view
    }
}
