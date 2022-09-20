import UIKit

final class SortPickerTableViewCell: UITableViewCell, ModalPickerCellProtocol {
    typealias Model = SortPickerTableViewCellModel

    var checkmarked: Bool = false

    private enum LayoutConstants {
        static let iconSize: CGFloat = 20
    }

    private let iconImageView = UIImageView()
    private let title: UILabel = {
        let label = UILabel()
        label.font = .h5Title
        label.textColor = R.color.colorStrokeGray()
        return label
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        configure()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(model: SortPickerTableViewCellModel) {
        iconImageView.image = model.switchIsOn ? R.image.iconListSelectionOn() : nil
        title.text = model.title
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
        contentView.addSubview(iconImageView)
        contentView.addSubview(title)

        iconImageView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.size.equalTo(LayoutConstants.iconSize)
        }

        title.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalToSuperview().offset(UIConstants.accessoryItemsSpacing)
        }
    }
}
