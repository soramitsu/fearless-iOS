import Foundation
import UIKit

struct SelectExportAccountCellViewModel {
    let title: String
    let subtitle: String
    let hint: String
    let imageViewModel: RemoteImageViewModel?
    var isSelected: Bool
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
        static let chainImageViewSize = CGSize(width: 18, height: 18)
        static let checkMarkImageViewSize = CGSize(width: 16, height: 12)
    }

    // MARK: - UI

    private let backgroundTriangularedView: TriangularedView = {
        let view = TriangularedView()
        view.fillColor = R.color.colorBlack()!
        view.strokeWidth = 1.0
        view.strokeColor = R.color.colorPink()!
        view.highlightedStrokeColor = R.color.colorPink()!
        return view
    }()

    private let checkMarkImageView = UIImageView()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.font = .h5Title
        label.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        return label
    }()

    private let chainImageView = UIImageView()

    private let subtitleLabel: UILabel = {
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
        selectionStyle = .none
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Life cycle

    override func prepareForReuse() {
        super.prepareForReuse()
        chainImageView.kf.cancelDownloadTask()
    }

    override var isSelected: Bool {
        didSet {
            checkMarkImageView.image = isSelected ? R.image.iconCheckMark() : nil
        }
    }

    // MARK: - Public methods

    func bind(viewModel: SelectExportAccountCellViewModel) {
        isSelected = viewModel.isSelected

        titleLabel.text = viewModel.title
        subtitleLabel.text = viewModel.subtitle
        chainCountLabel.text = viewModel.hint
        viewModel.imageViewModel?.loadImage(
            on: chainImageView,
            targetSize: Constants.chainImageViewSize,
            animated: true
        )
    }

    // MARK: - Private methods

    private func setupLayout() {
        backgroundColor = R.color.colorBlack()!

        contentView.addSubview(backgroundTriangularedView)
        backgroundTriangularedView.snp.makeConstraints { make in
            make.edges.equalTo(Constants.edges)
        }

        backgroundTriangularedView.addSubview(checkMarkImageView)
        checkMarkImageView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(14)
            make.leading.equalToSuperview().offset(20)
            make.size.equalTo(Constants.checkMarkImageViewSize)
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
            make.size.equalTo(Constants.chainImageViewSize)
        }

        chainStackView.addArrangedSubview(chainImageView)
        chainStackView.addArrangedSubview(subtitleLabel)
        chainStackView.addArrangedSubview(createChainCountView())

        chainStackView.setCustomSpacing(11, after: chainImageView)
        chainStackView.setCustomSpacing(8, after: subtitleLabel)
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
