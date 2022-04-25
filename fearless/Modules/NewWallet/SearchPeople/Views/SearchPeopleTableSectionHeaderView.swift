import UIKit

final class SearchPeopleTableSectionHeaderView: UIView {
    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = R.color.colorAlmostWhite()
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setupLayout() {
        addSubview(titleLabel)

        titleLabel.snp.makeConstraints { make in
            make.leading.top.equalToSuperview().offset(UIConstants.defaultOffset)
            make.trailing.bottom.equalToSuperview().inset(UIConstants.defaultOffset)
        }
    }
}
