import UIKit
import SoraUI
import SoraFoundation

protocol AnalyticsPeriodViewDelegate: AnyObject {
    func didSelect(period: AnalyticsPeriod)
}

final class AnalyticsPeriodView: UIView {
    weak var delegate: AnalyticsPeriodViewDelegate?

    typealias Button = AnalyticsBottomSheetButton<AnalyticsPeriod>
    private let weeklyButton = Button(model: .weekly)
    private let monthlyButton = Button(model: .monthly)
    private let yearlyButton = Button(model: .yearly)

    private var buttons: [AnalyticsBottomSheetButton<AnalyticsPeriod>] {
        [weeklyButton, monthlyButton, yearlyButton]
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
        buttons.forEach { $0.addTarget(self, action: #selector(handlePeriodButton(button:)), for: .touchUpInside) }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        let buttonsStackView: UIView = .hStack(
            spacing: 8,
            [weeklyButton, monthlyButton, yearlyButton]
        )
        addSubview(buttonsStackView)
        buttonsStackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.height.equalTo(24)
        }
    }

    func bind(selectedPeriod: AnalyticsPeriod) {
        buttons.forEach { $0.isSelected = false }
        let selectedButton = buttons.first(where: { $0.model == selectedPeriod })
        selectedButton?.isSelected = true
    }

    @objc
    private func handlePeriodButton(button: UIControl) {
        guard let button = button as? AnalyticsBottomSheetButton<AnalyticsPeriod> else { return }
        delegate?.didSelect(period: button.model)
    }
}

extension AnalyticsPeriod: AnalyticsBottomSheetButtonModel {}
