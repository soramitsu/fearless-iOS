import UIKit

class FilterSectionHeaderView: UIView {
    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .h4Title
        label.textColor = R.color.colorWhite()
        return label
    }()

    init() {
        super.init(frame: .zero)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setupLayout() {
        addSubview(titleLabel)

        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(UIConstants.defaultOffset)
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.bottom.equalToSuperview().inset(UIConstants.defaultOffset)
        }
    }
}
