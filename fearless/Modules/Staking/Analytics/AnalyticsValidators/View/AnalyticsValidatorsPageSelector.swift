import UIKit
import SoraUI

protocol AnalyticsValidatorsPageSelectorDelegate: AnyObject {
    func didSelectPage(_ page: AnalyticsValidatorsPage)
}

final class AnalyticsValidatorsPageSelector: UIView {
    weak var delegate: AnalyticsValidatorsPageSelectorDelegate?

    typealias Button = AnalyticsBottomSheetButton<AnalyticsValidatorsPage>
    private let activityButton = Button(model: .activity)
    private let rewardsButton = Button(model: .rewards)

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = R.color.colorAlmostBlack()
        setupLayout()
        activityButton.addTarget(self, action: #selector(handleButton), for: .touchUpInside)
        rewardsButton.addTarget(self, action: #selector(handleButton), for: .touchUpInside)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        let contentView = UIView.hStack([activityButton, rewardsButton])
        contentView.spacing = 8

        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(16)
            make.height.equalTo(24.0)
            make.centerX.equalToSuperview()
            make.bottom.equalTo(safeAreaLayoutGuide)
        }
    }

    @objc
    private func handleButton(sender: UIControl) {
        guard let button = sender as? Button else { return }
        delegate?.didSelectPage(button.model)
    }

    func bind(selectedPage: AnalyticsValidatorsPage) {
        let selectedButton = [activityButton, rewardsButton].first(where: { $0.model == selectedPage })
        selectedButton?.isSelected = true
    }
}

extension AnalyticsValidatorsPage: AnalyticsBottomSheetButtonModel {}
