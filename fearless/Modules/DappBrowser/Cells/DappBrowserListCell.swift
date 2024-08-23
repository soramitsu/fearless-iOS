import UIKit
import SoraUI

struct DappBrowserListCellViewModel {
    let icon: ImageViewModelProtocol
    let iconUrl: URL
    let name: String
    let description: String?
    let dapp: TonDapp
}

final class DappBrowserListCell: UITableViewCell {
    enum Position {
        case top
        case middle
        case bottom
        case list
    }

    let containerView: TriangularedView = {
        let containerView = TriangularedView()
        containerView.fillColor = R.color.colorWhite4()!
        containerView.highlightedFillColor = R.color.colorWhite4()!
        containerView.shadowOpacity = 0
        return containerView
    }()

    let iconViewImage: UIImageView = {
        let imageView = UIImageView()
        imageView.clipsToBounds = true
        return imageView
    }()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .h5Title
        return label
    }()

    let descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textColor = R.color.colorWhite50()
        label.numberOfLines = 2
        return label
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        iconViewImage.kf.cancelDownloadTask()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        iconViewImage.layer.cornerRadius = 8
    }

    func configure(
        model: DappBrowserListCellViewModel,
        position: Position
    ) {
        titleLabel.text = model.name
        descriptionLabel.text = model.description
        iconViewImage.kf.setImage(with: model.iconUrl)

        switch position {
        case .top, .middle:
            containerView.cornerCut = .none
            containerView.cornersRaduis = .none
        case .bottom:
            containerView.cornerCut = .bottomRight
            containerView.cornersRaduis = .bottomLeft
        case .list:
            containerView.cornerCut = .none
            containerView.cornersRaduis = .none
            containerView.fillColor = R.color.colorBlack19()!
            containerView.fillColor = R.color.colorBlack19()!
            containerView.snp.remakeConstraints { make in
                make.top.bottom.equalToSuperview()
                make.leading.trailing.equalToSuperview().inset(4)
            }
        }
    }

    func setup() {
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        contentView.addSubview(containerView)
        containerView.addSubview(iconViewImage)
        let vStackView = UIFactory.default.createVerticalStackView(spacing: 0)
        containerView.addSubview(vStackView)
        vStackView.addArrangedSubview(titleLabel)
        vStackView.addArrangedSubview(descriptionLabel)

        containerView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(16)
        }
        iconViewImage.snp.makeConstraints { make in
            make.size.equalTo(40)
            make.leading.equalToSuperview().offset(12)
            make.centerY.equalToSuperview()
        }
        vStackView.snp.makeConstraints { make in
            make.top.bottom.greaterThanOrEqualToSuperview().priority(.low)
            make.leading.equalTo(iconViewImage.snp.trailing).offset(8)
            make.trailing.equalToSuperview().inset(8)
            make.centerY.equalToSuperview()
        }
    }
}
