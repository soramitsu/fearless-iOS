import Foundation
import UIKit

final class WalletConnectProposalDetailsTableCell: UITableViewCell {
    private enum Constants {
        static let iconSize = CGSize(width: 24, height: 24)
    }

    let view: DetailsTriangularedView = {
        let view = DetailsTriangularedView()
        view.fillColor = R.color.colorSemiBlack()!
        view.highlightedFillColor = R.color.colorSemiBlack()!
        view.titleLabel.font = .h5Title
        view.titleLabel.textColor = R.color.colorStrokeGray()
        view.subtitleLabel?.font = .p1Paragraph
        view.strokeColor = R.color.colorWhite8()!
        view.borderWidth = 1
        view.layout = .largeIconTitleSubtitle
        view.iconView.contentMode = .scaleAspectFit
        view.isUserInteractionEnabled = false
        return view
    }()

    let dropTriangleImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = R.image.dropTriangle()
        imageView.isHidden = true
        return imageView
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        separatorInset = .zero
        selectionStyle = .none
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        view.iconImage = nil
    }

    func bind(viewModel: WalletConnectProposalCellModel.DetailsViewModel) {
        view.title = viewModel.title
        view.subtitle = viewModel.subtitle
        viewModel.icon?.loadImage(
            on: view.iconView,
            placholder: R.image.iconOpenWeb(),
            targetSize: Constants.iconSize,
            animated: true
        )
    }

    // MARK: - Private methods

    private func setupLayout() {
        contentView.addSubview(view)
        view.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.bottom.equalToSuperview().inset(UIConstants.minimalOffset)
            make.height.equalTo(UIConstants.cellHeight64)
        }

        view.addSubview(dropTriangleImageView)
        dropTriangleImageView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
        }
    }
}
