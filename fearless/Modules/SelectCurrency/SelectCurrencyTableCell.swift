import Foundation
import UIKit

final class SelectCurrencyTableCell: UITableViewCell {
    private enum Constants {
        static let currencyImageViewSize = CGSize(width: 24, height: 24)
        static let accessoryImageViewSize = CGSize(width: 16, height: 12)
    }

    private let currencyImageView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFill
        return view
    }()

    private let title: UILabel = {
        let view = UILabel()
        view.font = .p1Paragraph
        view.textColor = R.color.colorWhite()!
        return view
    }()

    private let accessoryImageView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFill
        view.tintColor = R.color.colorWhite()
        return view
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isSelected: Bool {
        didSet {
            accessoryImageView.image = isSelected ? R.image.listCheckmarkIcon() : nil
        }
    }

    func bind(viewModel: SelectCurrencyCellViewModel) {
        isSelected = viewModel.isSelected

        title.text = viewModel.title
        viewModel.imageViewModel?.loadImage(
            on: currencyImageView,
            targetSize: Constants.currencyImageViewSize,
            animated: true
        )
    }

    private func setupLayout() {
        backgroundColor = R.color.colorBlack()!

        let separator = UIFactory.default.createSeparatorView()
        contentView.addSubview(separator)
        separator.snp.makeConstraints { make in
            make.height.equalTo(UIConstants.separatorHeight)
            make.leading.trailing.bottom.equalToSuperview()
        }

        let commonStackView = UIFactory.default.createHorizontalStackView(spacing: 12)
        contentView.addSubview(commonStackView)
        commonStackView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.centerY.equalToSuperview()
        }

        currencyImageView.snp.makeConstraints { make in
            make.size.equalTo(Constants.currencyImageViewSize)
        }

        accessoryImageView.snp.makeConstraints { make in
            make.size.equalTo(Constants.accessoryImageViewSize)
        }

        commonStackView.addArrangedSubview(currencyImageView)
        commonStackView.addArrangedSubview(title)
        commonStackView.addArrangedSubview(accessoryImageView)
    }
}
