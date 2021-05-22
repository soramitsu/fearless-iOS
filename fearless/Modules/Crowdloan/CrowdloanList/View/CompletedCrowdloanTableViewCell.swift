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
        label.numberOfLines = 0
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

        viewModel?.iconViewModel.cancel()
        iconImageView.image = nil
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: CompletedCrowdloanViewModel) {
        self.viewModel = viewModel

        titleLabel.text = viewModel.title
        detailsLabel.text = viewModel.description
        progressLabel.text = viewModel.progress

        if let image = viewModel.iconViewModel.image {
            iconImageView.image = image
        } else {
            viewModel.iconViewModel.loadImage { [weak self] image, _ in
                if let image = image {
                    self?.iconImageView.image = image
                }
            }
        }
    }

    private func configure() {
        backgroundColor = .clear

        selectedBackgroundView = UIView()
        selectedBackgroundView?.backgroundColor = R.color.colorCellSelection()

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
            make.left.equalToSuperview().inset(UIConstants.horizontalInset)
            make.size.equalTo(28)
            make.top.equalToSuperview().inset(11)
        }

        addSubview(titleLabel)

        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconImageView.snp.trailing).offset(UIConstants.horizontalInset)
            make.top.equalToSuperview().inset(12.0)
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
        }

        addSubview(detailsLabel)

        detailsLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.top.equalTo(titleLabel.snp.bottom).offset(4.0)
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
        }

        addSubview(progressLabel)

        progressLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.top.equalTo(detailsLabel.snp.bottom).offset(8.0)
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalToSuperview().inset(12.0)
        }
    }
}
