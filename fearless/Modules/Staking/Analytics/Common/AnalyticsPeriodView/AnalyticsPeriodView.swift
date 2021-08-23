import UIKit
import SoraUI
import SoraFoundation

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
        let buttons = periods.map { AnalyticsBottomSheetButton<AnalyticsPeriod>(model: $0) }
        buttons.forEach { button in
            button.addTarget(self, action: #selector(handlePeriodButton(button:)), for: .touchUpInside)
            buttonsStackView.addArrangedSubview(button)
        }
        setNeedsLayout()
        let selectedButton = buttons.first(where: { $0.model == selected })
        selectedButton?.isSelected = true
    }

    @objc
    private func handlePeriodButton(button: UIControl) {
        guard let button = button as? AnalyticsBottomSheetButton<AnalyticsPeriod> else { return }
        delegate?.didSelect(period: button.model)
    }
}

extension AnalyticsPeriod: AnalyticsBottomSheetButtonModel {}
