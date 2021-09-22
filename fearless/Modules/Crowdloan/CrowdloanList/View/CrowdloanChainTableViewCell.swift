import UIKit

final class CrowdloanChainTableViewCell: UITableViewCell {
    let networkSelectionView: DetailsTriangularedView = {
        let view = UIFactory.default.createDetailsView(with: .largeIconTitleSubtitle, filled: false)
        view.highlightedFillColor = R.color.colorCellSelection()!
        view.actionImage = R.image.iconHorMore()
        return view
    }()

    let descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = R.color.colorWhite()!
        label.numberOfLines = 0
        return label
    }()

    private var viewModel: CrowdloansChainViewModel?

    override func prepareForReuse() {
        super.prepareForReuse()

        viewModel?.imageViewModel?.cancel(on: networkSelectionView.iconView)
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        selectionStyle = .none

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: CrowdloansChainViewModel) {
        self.viewModel?.imageViewModel?.cancel(on: networkSelectionView.iconView)
        networkSelectionView.iconView.image = nil

        self.viewModel = viewModel

        networkSelectionView.title = viewModel.networkName
        networkSelectionView.subtitle = viewModel.balance

        viewModel.imageViewModel?.loadImage(
            on: networkSelectionView.iconView,
            targetSize: CGSize(width: 24.0, height: 24.0),
            animated: true
        )

        descriptionLabel.text = viewModel.description
    }

    private func setupLayout() {
        contentView.addSubview(networkSelectionView)

        networkSelectionView.snp.makeConstraints { make in
            make.left.right.top.equalToSuperview().inset(16.0)
            make.height.equalTo(48.0)
        }

        contentView.addSubview(descriptionLabel)

        descriptionLabel.snp.makeConstraints { make in
            make.top.equalTo(networkSelectionView.snp.bottom).offset(16.0)
            make.left.right.bottom.equalToSuperview().inset(16.0)
        }
    }
}
