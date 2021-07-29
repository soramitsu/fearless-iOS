import UIKit

protocol AnalyticsPeriodSelectorViewDelegate: AnyObject {
    func didSelectPrevious()
    func didSelectNext()
}

final class AnalyticsPeriodSelectorView: UIView {
    weak var delegate: AnalyticsPeriodSelectorViewDelegate?

    private let previousButton: UIButton = {
        let button = UIButton()
        button.setImage(R.image.iconSmallArrow(), for: .normal) // tODO iconPreviousArrow()
        return button
    }()

    private let periodLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = R.color.colorWhite()
        return label
    }()

    private let nextButton: UIButton = {
        let button = UIButton()
        button.setImage(R.image.iconSmallArrow(), for: .normal)
        return button
    }()

    let periodView = AnalyticsPeriodView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = R.color.colorAlmostBlack()
        setupLayout()
        previousButton.addTarget(self, action: #selector(handlePreviousButton), for: .touchUpInside)
        nextButton.addTarget(self, action: #selector(handleNextButton), for: .touchUpInside)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        let separator = UIView.createSeparator(color: R.color.colorDarkGray())
        let verticalStack = UIView.vStack(
            spacing: 16,
            [
                .hStack(
                    alignment: .center,
                    distribution: .equalSpacing,
                    [previousButton, UIView(), periodLabel, UIView(), nextButton]
                ),
                separator,
                periodView
            ]
        )

        addSubview(verticalStack)
        verticalStack.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.horizontalInset)
        }
        separator.snp.makeConstraints { $0.height.equalTo(UIConstants.separatorHeight) }
        periodView.snp.makeConstraints { $0.height.equalTo(24) }
    }

    @objc
    private func handlePreviousButton() {
        delegate?.didSelectPrevious()
    }

    @objc
    private func handleNextButton() {
        delegate?.didSelectNext()
    }

    func bind(viewModel: AnalyticsPeriodViewModel) {
        periodLabel.text = viewModel.periodTitle
        periodView.configure(periods: viewModel.periods, selected: viewModel.selectedPeriod)
        nextButton.isEnabled = viewModel.canSelectNextPeriod
    }
}
