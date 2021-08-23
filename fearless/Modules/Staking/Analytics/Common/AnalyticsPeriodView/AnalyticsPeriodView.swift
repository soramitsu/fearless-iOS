import UIKit
import SoraUI

protocol AnalyticsPeriodViewDelegate: AnyObject {
    func didSelect(period: AnalyticsPeriod)
}

final class AnalyticsPeriodView: UIView {
    weak var delegate: AnalyticsPeriodViewDelegate?

    private var periods: [AnalyticsPeriod] = []
    private var selectedPeriod: AnalyticsPeriod?

    private let buttonsStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.spacing = 8
        return stackView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(buttonsStackView)
        buttonsStackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.height.equalTo(24)
        }
    }

    func configure(periods: [AnalyticsPeriod], selected: AnalyticsPeriod) {
        self.periods = periods
        buttonsStackView.arrangedSubviews.forEach { view in
            view.removeFromSuperview()
        }
        let buttons = periods.map { AnalyticsPeriodButton(period: $0) }
        buttons.forEach { button in
            button.addTarget(self, action: #selector(handlePeriodButton(button:)), for: .touchUpInside)
            buttonsStackView.addArrangedSubview(button)
        }
        setNeedsLayout()
        let selectedButton = buttons.first(where: { $0.period == selected })
        selectedButton?.isSelected = true
    }

    @objc
    private func handlePeriodButton(button: UIControl) {
        guard let button = button as? AnalyticsPeriodButton else { return }
        delegate?.didSelect(period: button.period)
    }
}

private class AnalyticsPeriodButton: RoundedButton {
    let period: AnalyticsPeriod

    init(period: AnalyticsPeriod) {
        self.period = period
        super.init(frame: .zero)

        roundedBackgroundView?.cornerRadius = 20
        roundedBackgroundView?.shadowOpacity = 0.0
        roundedBackgroundView?.strokeColor = R.color.colorDarkGray()!
        roundedBackgroundView?.highlightedStrokeColor = R.color.colorDarkGray()!
        roundedBackgroundView?.strokeWidth = 1.0
        roundedBackgroundView?.fillColor = .clear
        roundedBackgroundView?.highlightedFillColor = R.color.colorDarkGray()!

        contentInsets = UIEdgeInsets(top: 5.5, left: 12, bottom: 5.5, right: 12)

        imageWithTitleView?.titleColor = R.color.colorTransparentText()
        imageWithTitleView?.highlightedTitleColor = .white
        imageWithTitleView?.title = period.title(for: .current)
        imageWithTitleView?.titleFont = .capsTitle
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
