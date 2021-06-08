import UIKit
import SoraUI

class YourValidatorListStatusSectionView: UITableViewHeaderFooterView {
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

    let descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textColor = R.color.colorLightGray()!
        label.numberOfLines = 0
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
            make.width.height.equalTo(8.0)
            make.top.equalToSuperview().offset(16)
        }

        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(indicatorView.snp.trailing).offset(8)
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.centerY.equalTo(indicatorView.snp.centerY)
        }

        addSubview(descriptionLabel)
        descriptionLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(UIConstants.horizontalInset)
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalTo(titleLabel.snp.bottom).offset(10)
            make.bottom.equalToSuperview().inset(8)
        }
    }

    func bind(title: String?, description: String?, for status: YourValidatorListSectionStatus) {
        if let title = title {
            titleLabel.text = title.uppercased()
            titleLabel.isHidden = false
            indicatorView.isHidden = false
        } else {
            titleLabel.isHidden = true
            indicatorView.isHidden = true

            descriptionLabel.snp.updateConstraints { make in
                make.top.equalTo(titleLabel.snp.bottom).offset(-titleLabel.intrinsicContentSize.height)
            }
        }

        if let description = description {
            descriptionLabel.text = description
        } else {
            descriptionLabel.removeFromSuperview()
        }

        let color: UIColor = {
            switch status {
            case .stakeAllocated:
                return R.color.colorGreen()!
            default:
                return R.color.colorLightGray()!
            }
        }()

        titleLabel.textColor = color
        indicatorView.fillColor = color
    }
}
