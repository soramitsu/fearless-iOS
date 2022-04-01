import Foundation
import UIKit

struct ExportAccoutInfo {
    let chainName = "Polkadot"
    let chainImage = R.image.iconPolkadotAsset()
    let chainCount = "+ 18 others"
}

final class SelectableExportAccountTableCell: UITableViewCell {
    private enum Constants {
        static let edges = UIEdgeInsets(
            top: 8,
            left: UIConstants.horizontalInset,
            bottom: 8,
            right: UIConstants.horizontalInset
        )
        static let corderRadius: CGFloat = 3
    }

    // MARK: - UI

    private let backgroundTriangularedView: TriangularedView = {
        let view = TriangularedView()
        view.fillColor = R.color.colorBlack()!
        view.strokeWidth = 1.0
        view.strokeColor = R.color.colorAccent()!
        view.highlightedStrokeColor = R.color.colorAccent()!
        return view
    }()

    private let checkMarkImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = R.image.iconCheckMark()
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.font = .h5Title
        label.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        return label
    }()

    private let chainImageView = UIImageView()

    private let chainNameLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textColor = R.color.colorWhite()
        label.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        return label
    }()

    private let chainCountLabel: UILabel = {
        let label = UILabel()
        label.font = .p3Paragraph
        label.textColor = R.color.colorLightGray()
        label.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        return label
    }()

    // MARK: - Constructor

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Public methods

    func bind(viewModel: ExportAccoutInfo) {
        titleLabel.text = "Accounts with one key"
        chainNameLabel.text = viewModel.chainName
        chainImageView.image = viewModel.chainImage
        chainCountLabel.text = viewModel.chainCount
    }

    // MARK: - Private methods

    private func setupLayout() {
        contentView.addSubview(backgroundTriangularedView)
        backgroundTriangularedView.snp.makeConstraints { make in
            make.edges.equalTo(Constants.edges)
        }

        backgroundTriangularedView.addSubview(checkMarkImageView)
        checkMarkImageView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(14)
            make.leading.equalToSuperview().offset(20)
            make.width.equalTo(16)
            make.height.equalTo(12)
        }

        backgroundTriangularedView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(checkMarkImageView.snp.top)
            make.leading.equalTo(checkMarkImageView.snp.trailing).offset(19)
            make.trailing.greaterThanOrEqualToSuperview().inset(16)
        }

        let chainStackView = UIFactory.default.createHorizontalStackView()
        backgroundTriangularedView.addSubview(chainStackView)
        chainStackView.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(11)
            make.leading.equalTo(titleLabel.snp.leading)
            make.trailing.greaterThanOrEqualToSuperview().inset(16).priority(.low)
            make.bottom.equalToSuperview().inset(14)
        }

        chainImageView.snp.makeConstraints { make in
            make.width.height.equalTo(18)
        }

        chainStackView.addArrangedSubview(chainImageView)
        chainStackView.addArrangedSubview(chainNameLabel)
        chainStackView.addArrangedSubview(createChainCountView())

        chainStackView.setCustomSpacing(11, after: chainImageView)
        chainStackView.setCustomSpacing(8, after: chainNameLabel)
    }

    private func createChainCountView() -> UIView {
        let view = UIView()
        view.backgroundColor = R.color.colorDarkGray()
        view.layer.cornerRadius = Constants.corderRadius
        view.layer.masksToBounds = true
        view.setContentHuggingPriority(.defaultHigh, for: .vertical)

        view.addSubview(chainCountLabel)
        chainCountLabel.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview().inset(1)
            make.leading.trailing.equalToSuperview().inset(6)
        }
        return view
    }
}
