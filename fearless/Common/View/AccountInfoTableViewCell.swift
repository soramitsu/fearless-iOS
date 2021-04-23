import UIKit

protocol AccountInfoTableViewCellDelegate: AnyObject {
    func accountInfoCellDidReceiveAction(_ cell: AccountInfoTableViewCell)
}

final class AccountInfoTableViewCell: UITableViewCell {
    let detailsView: DetailsTriangularedView = {
        let detailsView = UIFactory().createDetailsView(with: .smallIconTitleSubtitle, filled: false)
        detailsView.titleLabel.lineBreakMode = .byTruncatingMiddle
        detailsView.subtitleLabel?.lineBreakMode = .byTruncatingMiddle
        detailsView.actionImage = R.image.iconMore()
        detailsView.highlightedFillColor = R.color.colorHighlightedPink()!
        detailsView.strokeColor = R.color.colorStrokeGray()!
        detailsView.borderWidth = 1
        return detailsView
    }()

    weak var delegate: AccountInfoTableViewCellDelegate?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        backgroundColor = .clear
        selectionStyle = .none

        setupLayout()

        detailsView.addTarget(self, action: #selector(actionDetails), for: .touchUpInside)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        // hide separator
        separatorInset = .init(top: 0, left: bounds.width, bottom: 0, right: 0)
    }

    private func setupLayout() {
        contentView.addSubview(detailsView)
        detailsView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.height.equalTo(52)
        }
    }

    @objc func actionDetails() {
        delegate?.accountInfoCellDidReceiveAction(self)
    }

    func bind(model: AccountInfoViewModel) {
        detailsView.title = model.title
        detailsView.subtitle = model.name
        detailsView.iconImage = model.icon

        setNeedsLayout()
    }
}
