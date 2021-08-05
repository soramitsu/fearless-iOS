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
        stackView.alignment = .center
        stackView.distribution = .fillEqually
        return stackView
    }()

//    let collectionView: UICollectionView = {
//        let layout = UICollectionViewFlowLayout()
//        layout.scrollDirection = .horizontal
//        layout.estimatedItemSize = .init(width: 83, height: 24)
//        layout.minimumInteritemSpacing = 8
//        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
//        collectionView.showsHorizontalScrollIndicator = false
//        collectionView.backgroundColor = .clear
//        return collectionView
//    }()

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
        buttons.forEach { buttonsStackView.addArrangedSubview($0) }
        setNeedsLayout()
        let selectedButton = buttons.first(where: { $0.period == selected })
        selectedButton?.isSelected = true
    }

    @objc
    private func handlePeriodButton(button _: AnalyticsPeriodButton) {}
}

private class AnalyticsPeriodButton: RoundedButton {
    let period: AnalyticsPeriod

    init(period: AnalyticsPeriod) {
        self.period = period
        super.init(frame: .zero)

        roundedBackgroundView?.cornerRadius = 20
        roundedBackgroundView?.shadowOpacity = 0.0

        // contentInsets = UIEdgeInsets(top: 5.5, left: 12, bottom: 5.5, right: 12)
        roundedBackgroundView?.fillColor = .clear
        roundedBackgroundView?.highlightedFillColor = R.color.colorDarkGray()!

        imageWithTitleView?.titleColor = R.color.colorTransparentText()
        imageWithTitleView?.highlightedTitleColor = R.color.colorWhite()!
        imageWithTitleView?.title = period.title(for: .current)
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
