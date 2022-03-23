import UIKit

class ManageAssetsTableViewCell: UITableViewCell {
    private enum LayoutConstants {
        static let iconSize: CGFloat = 24
    }

    let chainIconImageView: UIImageView = {
        let imageView = UIImageView()
        return imageView
    }()

    let chainNameLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = .white
        return label
    }()

    let tokenBalanceLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textColor = R.color.colorTransparentText()
        return label
    }()

    let switcher: UISwitch = {
        let switcher = UISwitch()
        switcher.onTintColor = R.color.colorAccent()
        return switcher
    }()

    let dragButton: UIButton = {
        let button = UIButton()
        return button
    }()

    let chainOptionsView: ScrollableContainerView = {
        let containerView = ScrollableContainerView()
        containerView.stackView.axis = .horizontal
        containerView.stackView.distribution = .fillProportionally
        containerView.stackView.alignment = .fill
        containerView.stackView.spacing = UIConstants.defaultOffset
        return containerView
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        configure()
        setupLayout()
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        chainIconImageView.kf.cancelDownloadTask()

        chainOptionsView.stackView.arrangedSubviews.forEach { subview in
            chainOptionsView.stackView.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configure() {
        backgroundColor = .clear

        separatorInset = UIEdgeInsets(
            top: 0.0,
            left: UIConstants.horizontalInset,
            bottom: 0.0,
            right: UIConstants.horizontalInset
        )

        selectionStyle = .none
    }

    private func setupLayout() {
        addSubview(chainIconImageView)
        addSubview(chainNameLabel)
        addSubview(chainOptionsView)
        addSubview(tokenBalanceLabel)
        addSubview(switcher)
        addSubview(dragButton)

        chainIconImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.centerY.equalToSuperview()
            make.size.equalTo(LayoutConstants.iconSize)
        }

        dragButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.centerY.equalToSuperview()
            make.top.bottom.equalToSuperview()
        }

        switcher.snp.makeConstraints { make in
            make.trailing.equalTo(dragButton.snp.leading).inset(UIConstants.bigOffset)
            make.centerY.equalToSuperview()
        }

        chainNameLabel.snp.makeConstraints { make in
            make.leading.equalTo(chainIconImageView.snp.trailing).offset(UIConstants.bigOffset)
            make.top.equalToSuperview().offset(UIConstants.defaultOffset)
        }

        chainOptionsView.snp.makeConstraints { make in
            make.leading.equalTo(chainNameLabel.snp.trailing).offset(UIConstants.minimalOffset)
            make.centerY.equalTo(chainNameLabel.snp.centerY)
            make.trailing.equalTo(switcher.snp.leading).inset(UIConstants.bigOffset)
        }

        tokenBalanceLabel.snp.makeConstraints { make in
            make.leading.equalTo(chainNameLabel.snp.leading)
            make.top.equalTo(chainNameLabel.snp.bottom).offset(UIConstants.minimalOffset)
            make.bottom.equalToSuperview().inset(UIConstants.defaultOffset)
        }
    }
}
