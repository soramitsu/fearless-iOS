import UIKit

final class HintView: UIView {
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
            make.leading.equalToSuperview()
            make.top.equalToSuperview().inset(16.0)
            make.size.equalTo(14.0)
        }

        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(iconView.snp.top).offset(-1.0)
            make.leading.equalTo(iconView.snp.trailing).offset(9.0)
            make.trailing.equalToSuperview()
        }

        snp.makeConstraints { make in
            make.bottom.equalTo(titleLabel)
        }
    }
}
