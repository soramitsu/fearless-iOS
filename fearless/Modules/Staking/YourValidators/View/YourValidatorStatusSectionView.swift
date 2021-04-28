import UIKit
import SoraUI

class YourValidatorStatusSectionView: UITableViewHeaderFooterView {
    let indicatorView: RoundedView = {
        let view = RoundedView()
        view.cornerRadius = 4.0
        return view
    }()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .capsTitle
        return label
    }()

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)

        backgroundView = UIView()
        backgroundView?.backgroundColor = R.color.colorBlack()

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(indicatorView)
        indicatorView.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(UIConstants.horizontalInset)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(8.0)
        }

        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(indicatorView.snp.trailing).offset(8)
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.centerY.equalToSuperview()
        }
    }

    func bind(title: String, for status: YourValidatorsSectionStatus) {
        titleLabel.text = title.uppercased()

        let color: UIColor = {
            switch status {
            case .active:
                return R.color.colorGreen()!
            case .slashed:
                return R.color.colorRed()!
            case .inactive, .waiting, .pending:
                return R.color.colorLightGray()!
            }
        }()

        titleLabel.textColor = color
        indicatorView.fillColor = color
    }
}
