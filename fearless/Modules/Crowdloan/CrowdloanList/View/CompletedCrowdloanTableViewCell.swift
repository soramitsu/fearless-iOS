import UIKit

final class CompletedCrowdloanTableViewCell: UITableViewCell {
    let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorStrokeGray()
        label.font = .p1Paragraph
        return label
    }()

    let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    let detailsLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorStrokeGray()
        label.font = .p2Paragraph
        label.lineBreakMode = .byTruncatingMiddle
        return label
    }()

    let progressLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorStrokeGray()
        label.font = .p2Paragraph
        return label
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        configure()
        setupLayout()
    }

    private var viewModel: CompletedCrowdloanViewModel?

    override func prepareForReuse() {
        super.prepareForReuse()

        viewModel?.iconViewModel.cancel(on: iconImageView)
        viewModel = nil

        iconImageView.image = nil
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: CompletedCrowdloanViewModel) {
        self.viewModel = viewModel

        titleLabel.text = viewModel.title

        switch viewModel.description {
        case let .address(address):
            detailsLabel.numberOfLines = 1
            detailsLabel.text = address
        case let .text(text):
            detailsLabel.numberOfLines = 0
            detailsLabel.text = text
        }

        progressLabel.text = viewModel.progress

        viewModel.iconViewModel.loadImage(
            on: iconImageView,
            targetSize: CrowdloanViewConstants.iconSize,
            animated: true
        )
    }

    private func configure() {
        backgroundColor = .clear
        selectionStyle = .none

        separatorInset = UIEdgeInsets(
            top: 0.0,
            left: UIConstants.horizontalInset,
            bottom: 0.0,
            right: UIConstants.horizontalInset
        )
    }

    private func setupLayout() {
        contentView.addSubview(iconImageView)

        iconImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(UIConstants.horizontalInset)
            make.size.equalTo(CrowdloanViewConstants.iconSize)
            make.top.equalToSuperview().inset(11)
        }

        contentView.addSubview(titleLabel)

        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconImageView.snp.trailing).offset(UIConstants.horizontalInset)
            make.top.equalToSuperview().inset(12.0)
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
        }

        contentView.addSubview(detailsLabel)

        detailsLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.top.equalTo(titleLabel.snp.bottom).offset(4.0)
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
        }

        contentView.addSubview(progressLabel)

        progressLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.top.equalTo(detailsLabel.snp.bottom).offset(8.0)
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalToSuperview().inset(12.0)
        }
    }
}
