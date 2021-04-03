import UIKit

final class AccountInfoTableViewCell: UITableViewCell {
    let detailsView: DetailsTriangularedView = {
        let detailsView = UIFactory().createDetailsView(with: .smallIconTitleSubtitle, filled: true)
        detailsView.titleLabel.lineBreakMode = .byTruncatingMiddle
        detailsView.subtitleLabel?.lineBreakMode = .byTruncatingMiddle
        detailsView.actionImage = R.image.iconMore()
        return detailsView
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        backgroundColor = .clear
        setupLayout()
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
            make.bottom.equalToSuperview()
            make.height.equalTo(52)
        }
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)

        detailsView.set(highlighted: highlighted, animated: animated)
    }

    func bind(model: ValidatorInfoAccountViewModelProtocol) {
        detailsView.title = model.name
        detailsView.subtitle = model.address
        detailsView.iconImage = model.icon

        setNeedsLayout()
    }
}
