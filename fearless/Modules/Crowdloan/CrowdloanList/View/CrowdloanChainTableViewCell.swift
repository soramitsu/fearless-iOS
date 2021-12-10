import UIKit

final class CrowdloanChainTableViewCell: UITableViewCell {
    let chainSelectionView: DetailsTriangularedView = {
        let view = UIFactory.default.createChainAssetSelectionView()
        view.strokeColor = R.color.colorStrokeGray()!
        view.highlightedStrokeColor = R.color.colorStrokeGray()!
        view.borderWidth = 1.0
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

        viewModel?.imageViewModel?.cancel(on: chainSelectionView.iconView)
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        backgroundColor = .clear
        selectionStyle = .none

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: CrowdloansChainViewModel) {
        self.viewModel?.imageViewModel?.cancel(on: chainSelectionView.iconView)
        chainSelectionView.iconView.image = nil

        self.viewModel = viewModel

        chainSelectionView.title = viewModel.networkName
        chainSelectionView.subtitle = viewModel.balance

        let iconSize = 2 * chainSelectionView.iconRadius
        viewModel.imageViewModel?.loadImage(
            on: chainSelectionView.iconView,
            targetSize: CGSize(width: iconSize, height: iconSize),
            animated: true
        )

        descriptionLabel.text = viewModel.description
    }

    private func setupLayout() {
        contentView.addSubview(chainSelectionView)

        chainSelectionView.snp.makeConstraints { make in
            make.left.right.top.equalToSuperview().inset(16.0)
            make.height.equalTo(48.0)
        }

        contentView.addSubview(descriptionLabel)

        descriptionLabel.snp.makeConstraints { make in
            make.top.equalTo(chainSelectionView.snp.bottom).offset(16.0)
            make.left.right.bottom.equalToSuperview().inset(16.0)
        }
    }
}
