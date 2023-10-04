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
        view.contentInsets = UIEdgeInsets(top: 8.0, left: 8.0, bottom: 8.0, right: 8.0)
    }

    func bind(viewModel: WalletConnectProposalCellModel.DetailsViewModel) {
        view.title = viewModel.title
        view.subtitle = viewModel.subtitle
        if viewModel.icon != nil {
            view.layout = .largeIconTitleSubtitle
            viewModel.icon?.loadImage(
                on: view.iconView,
                placholder: R.image.iconOpenWeb(),
                targetSize: Constants.iconSize,
                animated: true
            )
        } else {
            view.layout = .withoutIcon
        }
        if !dropTriangleImageView.isHidden {
            view.contentInsets.right = UIConstants.bigOffset * 2
        }
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
