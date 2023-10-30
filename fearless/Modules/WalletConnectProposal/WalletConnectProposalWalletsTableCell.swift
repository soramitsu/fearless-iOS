import Foundation
import UIKit

final class WalletConnectProposalWalletsTableCell: UITableViewCell {
    private enum Constants {
        static let iconSize = CGSize(width: 24, height: 24)
    }

    var view: DetailsTriangularedView = {
        let view = DetailsTriangularedView()
        view.fillColor = R.color.colorSemiBlack()!
        view.highlightedFillColor = R.color.colorSemiBlack()!
        view.titleLabel.font = .h5Title
        view.strokeColor = R.color.colorWhite8()!
        view.borderWidth = 1
        view.layout = .singleTitle
        view.highlightedStrokeColor = R.color.colorPink()!
        view.iconImage = R.image.iconBirdGreen()
        view.isUserInteractionEnabled = false
        return view
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

    func bind(viewModel: WalletConnectProposalCellModel.WalletViewModel) {
        view.title = viewModel.walletName
        view.set(highlighted: viewModel.isSelected, animated: false)
    }

    // MARK: - Private methods

    private func setupLayout() {
        contentView.addSubview(view)
        view.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.bottom.equalToSuperview().inset(UIConstants.minimalOffset)
            make.height.equalTo(UIConstants.cellHeight64)
        }
    }
}
