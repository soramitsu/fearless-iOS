import UIKit
import SoraUI

final class ValidatorInfoEmptyStakeCell: UITableViewCell {
    private enum Constants {
        static let verticalInset: CGFloat = 0
        static let horizontalInset: CGFloat = 95
    }

    let emptyStateView: EmptyStateView = {
        let view = EmptyStateView()
        view.titleFont = .p2Paragraph
        view.titleColor = R.color.colorLightGray()!
        view.image = R.image.iconEmptyStake()
        return view
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        backgroundColor = .clear
        selectionStyle = .none
        separatorInset = .init(
            top: 0,
            left: UIConstants.horizontalInset,
            bottom: 0,
            right: UIConstants.horizontalInset
        )

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setupLayout() {
        contentView.addSubview(emptyStateView)
        emptyStateView.snp.makeConstraints { make in
            make.bottom.top.equalToSuperview().inset(Constants.verticalInset)
            make.leading.trailing.equalToSuperview().inset(Constants.horizontalInset)
        }
    }

    func bind(model: ImageWithTitleViewModelProtocol) {
        emptyStateView.title = model.title
        emptyStateView.image = model.image
    }
}
