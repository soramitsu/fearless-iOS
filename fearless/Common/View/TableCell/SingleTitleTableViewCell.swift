import UIKit

class SingleTitleTableViewCell: UITableViewCell {
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        configure()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(title: String, icon: UIImage? = nil) {
        textLabel?.text = title

        if let icon = icon {
            imageView?.image = icon
        }
    }

    private func configure() {
        backgroundColor = .clear

        let selectedBackgroundView = UIView()
        selectedBackgroundView.backgroundColor = R.color.colorCellSelection()!
        self.selectedBackgroundView = selectedBackgroundView

        textLabel?.textColor = R.color.colorWhite()
        textLabel?.font = .p1Paragraph

        separatorInset = UIEdgeInsets(
            top: 0.0,
            left: UIConstants.horizontalInset,
            bottom: 0.0,
            right: UIConstants.horizontalInset
        )

        accessoryView = UIImageView(image: R.image.iconSmallArrow())
    }
}
