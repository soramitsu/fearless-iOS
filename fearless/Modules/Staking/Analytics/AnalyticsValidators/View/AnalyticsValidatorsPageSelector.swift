import UIKit
import SoraUI

protocol AnalyticsValidatorsPageSelectorDelegate: AnyObject {
    func didSelectPage(_ page: AnalyticsValidatorsPage)
}

final class AnalyticsValidatorsPageSelector: UIView {
    weak var delegate: AnalyticsValidatorsPageSelectorDelegate?

    typealias Button = AnalyticsMagentaButton<AnalyticsValidatorsPage>
    private let buttons: [Button] = {
        AnalyticsValidatorsPage.allCases.map { Button(model: $0) }
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
        buttons.forEach { $0.addTarget(self, action: #selector(handleButton(button:)), for: .touchUpInside) }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        let contentView = UIView.hStack(spacing: 8, buttons)

        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    @objc
    private func handleButton(button: UIControl) {
        guard let button = button as? Button else { return }
        delegate?.didSelectPage(button.model)
    }

    func bind(selectedPage: AnalyticsValidatorsPage) {
        buttons.forEach { $0.isSelected = $0.model == selectedPage }
    }
}

extension AnalyticsValidatorsPage: AnalyticsMagentaButtonModel {}
