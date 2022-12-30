import UIKit

final class MainNftContainerViewLayout: UIView {
    let attentionImageView: UIImageView = {
        let imageView = UIImageView()
        let image = R.image.iconAttention()?.withRenderingMode(.alwaysTemplate)
        imageView.image = image
        imageView.tintColor = R.color.colorWhite16()!
        return imageView
    }()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Sumimasen!"
        label.font = .h3Title
        return label
    }()

    let descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = .p0Paragraph
        label.text = "NFTs are going to be here soon"
        return label
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
        addSubview(attentionImageView)
        attentionImageView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(safeAreaLayoutGuide.snp.top).offset(65)
        }

        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(attentionImageView.snp.bottom).offset(16)
        }

        addSubview(descriptionLabel)
        descriptionLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(titleLabel.snp.bottom).offset(16)
        }
    }
}
