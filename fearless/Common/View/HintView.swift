import UIKit

class HintView: UIView {
    private enum Constants {
        static let iconSize: CGFloat = 16
    }

    let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorLightGray()
        label.font = .p2Paragraph
        label.numberOfLines = 0
        return label
    }()

    let iconView: UIImageView = {
        let view = UIImageView(image: R.image.iconInfoFilled()?.withRenderingMode(.alwaysTemplate))
        view.tintColor = R.color.colorGray()
        return view
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
        addSubview(iconView)
        iconView.snp.makeConstraints { make in
            make.leading.top.equalToSuperview()
            make.size.equalTo(Constants.iconSize)
        }

        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(iconView.snp.top).offset(-1.0)
            make.leading.equalTo(iconView.snp.trailing).offset(9.0)
            make.trailing.bottom.equalToSuperview()
        }
    }

    func setIconHidden(_ hidden: Bool) {
        iconView.isHidden = hidden

        if hidden {
            iconView.snp.remakeConstraints { make in
                make.size.equalTo(CGSize.zero)
            }
            titleLabel.snp.remakeConstraints { make in
                make.top.equalToSuperview()
                make.leading.equalToSuperview()
                make.trailing.bottom.equalToSuperview()
            }
        } else {
            iconView.snp.remakeConstraints { make in
                make.leading.top.equalToSuperview()
                make.size.equalTo(Constants.iconSize)
            }
            titleLabel.snp.remakeConstraints { make in
                make.top.equalTo(iconView.snp.top).offset(-1.0)
                make.leading.equalTo(iconView.snp.trailing).offset(9.0)
                make.trailing.bottom.equalToSuperview()
            }
        }
    }
}
