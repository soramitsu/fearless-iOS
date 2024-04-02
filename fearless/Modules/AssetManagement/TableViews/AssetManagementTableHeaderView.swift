import Foundation
import UIKit

final class AssetManagementTableHeaderView: UITableViewHeaderFooterView {
    let assetImageView = UIImageView()

    let symbolLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.font = .p1Paragraph
        return label
    }()

    let countLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorStrokeGray()
        label.font = .h5Title
        return label
    }()

    let textContainer = UIFactory.default.createVerticalStackView()

    let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .center
        return imageView
    }()

    var viewModel: AssetManagementTableSection?

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        backgroundView = UIView(frame: bounds)
        backgroundView?.backgroundColor = R.color.colorBlack19()

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        assetImageView.image = nil
        assetImageView.highlightedImage = nil
        viewModel?.assetImage?.cancel(on: assetImageView)
        viewModel = nil
    }

    func bind(viewModel: AssetManagementTableSection) {
        self.viewModel = viewModel

        viewModel.assetImage?.loadImage(
            on: assetImageView,
            targetSize: CGSize(width: 32, height: 32),
            animated: true,
            cornerRadius: 16,
            completionHandler: { [weak self, viewModel] result in
                guard let image = try? result.get() else {
                    return
                }
                self?.assetImageView.highlightedImage = image.image.monochrome()
                self?.assetImageView.isHighlighted = viewModel.isAllDisabled
            }
        )
        symbolLabel.text = viewModel.assetName
        countLabel.text = viewModel.assetCount
        imageView.image = viewModel.isExpanded ? R.image.iconArrowUp() : R.image.iconSmallArrowDown()
    }

    // MARK: - Private methods

    private func setupLayout() {
        [
            assetImageView,
            textContainer,
            imageView
        ].forEach { contentView.addSubview($0) }

        [
            symbolLabel,
            countLabel
        ].forEach { textContainer.addArrangedSubview($0) }

        contentView.snp.makeConstraints { make in
            make.height.equalTo(55)
            make.width.equalToSuperview()
        }

        assetImageView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalToSuperview().inset(16)
            make.size.equalTo(32)
        }

        textContainer.snp.makeConstraints { make in
            make.leading.equalTo(assetImageView.snp.trailing).offset(12)
            make.centerY.equalToSuperview()
        }

        symbolLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
        }

        countLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
        }

        imageView.snp.makeConstraints { make in
            make.leading.equalTo(textContainer.snp.trailing)
            make.trailing.equalToSuperview().inset(16)
            make.centerY.equalToSuperview()
            make.size.equalTo(16)
        }
    }
}
