import UIKit

final class TonWebBridgeHeaderView: UIView {
    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .h3Title
        label.textColor = R.color.colorWhite()
        label.textAlignment = .center
        return label
    }()

    let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textColor = R.color.colorGray()
        label.textAlignment = .center
        return label
    }()

    let contentView = UIView()

    let closeButton: UIButton = {
        let button = UIButton()
        button.setImage(R.image.iconClose(), for: .normal)
        button.layer.masksToBounds = true
        button.backgroundColor = R.color.colorWhite8()
        return button
    }()

    let backButton: UIButton = {
        let button = UIButton()
        button.setImage(R.image.iconBack(), for: .normal)
        button.layer.masksToBounds = true
        button.backgroundColor = R.color.colorWhite8()
        return button
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setTitle(_ title: String?) {
        titleLabel.text = title
    }

    func setSubtitle(_ title: String, isSecured: Bool) {
        let subtitleResult = NSMutableAttributedString()
        if isSecured, let lockImage = UIImage(systemName: "lock.fill") {
            let attachment = NSTextAttachment(image: lockImage)
            let attachmentString = NSMutableAttributedString(attachment: attachment)
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center
            attachmentString.addAttributes(
                [
                    .foregroundColor: R.color.colorGray()!,
                    .paragraphStyle: paragraphStyle
                ],
                range: NSRange(
                    location: 0,
                    length: attachmentString.length
                )
            )
            subtitleResult.append(attachmentString)
            subtitleResult.append(NSAttributedString(string: " "))
        }

        let attributtedTitle = NSAttributedString(string: title)
        subtitleResult.append(attributtedTitle)

        subtitleLabel.attributedText = subtitleResult
    }

    private func setup() {
        addSubview(contentView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(subtitleLabel)
        contentView.addSubview(closeButton)
        contentView.addSubview(backButton)

        setupConstraints()
    }

    private func setupConstraints() {
        backgroundColor = R.color.colorBlack19()
        contentView.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide.snp.top)
            make.left.right.bottom.equalTo(self)
            make.height.equalTo(64)
        }

        closeButton.snp.makeConstraints { make in
            make.right.equalTo(contentView).offset(-8)
            make.centerY.equalTo(contentView)
            make.size.equalTo(32)
        }

        backButton.snp.makeConstraints { make in
            make.left.equalTo(contentView).offset(8)
            make.centerY.equalTo(contentView)
            make.size.equalTo(32)
        }

        titleLabel.snp.makeConstraints { make in
            make.bottom.equalTo(contentView.snp.centerY)
            make.leading.equalTo(backButton.snp.trailing)
            make.trailing.equalTo(closeButton.snp.leading)
            make.width.lessThanOrEqualToSuperview()
        }

        subtitleLabel.snp.makeConstraints { make in
            make.top.equalTo(contentView.snp.centerY)
            make.leading.equalTo(backButton.snp.trailing)
            make.trailing.equalTo(closeButton.snp.leading)
            make.width.lessThanOrEqualToSuperview()
        }
    }
}
