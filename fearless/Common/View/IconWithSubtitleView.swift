import UIKit

class IconWithSubtitleView: UIView {
    enum Constants {
        static let iconSize: CGFloat = 80.0
    }

    let iconView: UIImageView = {
        let imageView = UIImageView()
        imageView.backgroundColor = R.color.colorWhite()
        return imageView
    }()

    let subtitleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.textAlignment = .center
        label.font = .h2Title
        label.numberOfLines = 2
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupStyle()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupStyle() {
        backgroundColor = .clear
    }

    private func setupLayout() {
        addSubview(iconView)

        iconView.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(24.0)
            make.centerX.equalToSuperview()
            make.size.equalTo(Constants.iconSize)
        }

        addSubview(subtitleLabel)

        subtitleLabel.snp.makeConstraints { make in
            make.top.equalTo(iconView.snp.bottom).offset(16.0)
            make.bottom.equalToSuperview().inset(16.0)
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
        }
    }
}
