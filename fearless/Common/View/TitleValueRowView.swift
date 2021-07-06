import UIKit

class TitleValueRowView: BaseRowView {
    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = R.color.colorWhite()
        return label
    }()

    let detailsLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = R.color.colorAccent()
        return label
    }()

    let arrowIconView: UIView = {
        let imageView = UIImageView(image: R.image.iconSmallArrow())
        imageView.tintColor = .white
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    private func setupLayout() {
        contentView?.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(UIConstants.horizontalInset)
            make.centerY.equalToSuperview()
        }

        contentView?.addSubview(arrowIconView)
        arrowIconView.snp.makeConstraints { make in
            make.trailing.centerY.equalToSuperview()
            make.size.equalTo(24.0)
        }

        contentView?.addSubview(detailsLabel)
        detailsLabel.snp.makeConstraints { make in
            make.trailing.equalTo(arrowIconView.snp.leading).offset(-8.0)
            make.centerY.equalToSuperview()
            make.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(8.0)
        }
    }
}
