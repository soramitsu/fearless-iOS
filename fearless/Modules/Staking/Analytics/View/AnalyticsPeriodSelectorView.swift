import UIKit

protocol AnalyticsPeriodSelectorViewDelegate: AnyObject {
    func didSelectPrevious()
    func didSelectNext()
}

final class AnalyticsPeriodSelectorView: UIView {
    weak var delegate: AnalyticsPeriodSelectorViewDelegate?

    let previousButton: UIButton = {
        let button = UIButton()
        button.setImage(R.image.iconSmallArrow(), for: .normal)
        return button
    }()

    let periodLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = R.color.colorWhite()
        return label
    }()

    let nextButton: UIButton = {
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
        let stack: UIView = .hStack(
            alignment: .center,
            distribution: .equalSpacing,
            [previousButton, UIView(), periodLabel, UIView(), nextButton]
        )
        addSubview(stack)
        stack.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(16)
            make.height.equalTo(48)
        }

        addSubview(periodView)
        periodView.snp.makeConstraints { make in
            make.top.equalTo(stack.snp.bottom)
            make.height.equalTo(24)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(safeAreaLayoutGuide).inset(16)
        }
    }

    @objc
    private func handlePreviousButton() {
        delegate?.didSelectPrevious()
    }

    @objc
    private func handleNextButton() {
        delegate?.didSelectNext()
    }
}
