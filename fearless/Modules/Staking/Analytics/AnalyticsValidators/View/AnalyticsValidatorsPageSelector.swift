import UIKit
import SoraUI

protocol AnalyticsValidatorsPageSelectorDelegate: AnyObject {
    func didSelectPage(_ page: AnalyticsValidatorsPage)
}

final class AnalyticsValidatorsPageSelector: UIView {
    weak var delegate: AnalyticsValidatorsPageSelectorDelegate?

    private let activityButton = AnalyticsPageButton(page: .activity)
    private let rewardsButton = AnalyticsPageButton(page: .rewards)

    lazy var contentView: UIView = {
        UIView.hStack([activityButton, rewardsButton])
    }()

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
        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(16)
            make.height.equalTo(24)
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview()
        }
    }

    @objc
    private func handleButton(sender: UIControl) {
        guard let button = sender as? AnalyticsPageButton else { return }
        delegate?.didSelectPage(button.page)
    }
}

private class AnalyticsPageButton: RoundedButton {
    let page: AnalyticsValidatorsPage

    init(page: AnalyticsValidatorsPage) {
        self.page = page
        super.init(frame: .zero)

        roundedBackgroundView?.cornerRadius = 20
        roundedBackgroundView?.shadowOpacity = 0.0

        // contentInsets = UIEdgeInsets(top: 5.5, left: 12, bottom: 5.5, right: 12)
        roundedBackgroundView?.fillColor = .clear
        roundedBackgroundView?.highlightedFillColor = R.color.colorDarkGray()!

        imageWithTitleView?.titleColor = R.color.colorTransparentText()
        imageWithTitleView?.highlightedTitleColor = R.color.colorWhite()!
        imageWithTitleView?.title = page.title(for: .current)
        imageWithTitleView?.titleFont = .capsTitle
        changesContentOpacityWhenHighlighted = true
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    //
    //    private func setupLayout() {
    //        contentView.addSubview(titleLabel)
    //        titleLabel.snp.makeConstraints { make in
    //            make.leading.trailing.equalToSuperview().inset(12)
    //            make.top.bottom.equalToSuperview().inset(5.5)
    //        }
    //    }

    //    private func setupBorder() {
    //        contentView.layer.cornerRadius = 12
    //        contentView.clipsToBounds = true
    //        contentView.layer.borderWidth = 2
    //        contentView.layer.borderColor = R.color.colorWhite()?.withAlphaComponent(0.16).cgColor
    //    }
}
