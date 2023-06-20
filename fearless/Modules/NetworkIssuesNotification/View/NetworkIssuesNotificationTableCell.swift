import Foundation
import UIKit

protocol NetworkIssuesNotificationTableCellDelegate: AnyObject {
    func didTapOnAction(with indexPath: IndexPath?)
}

final class NetworkIssuesNotificationTableCell: UITableViewCell {
    private enum Constants {
        static let chainImageViewSize = CGSize(width: 30, height: 30)
        static let actionButtonSize = CGSize(width: 85, height: 24)
        static let cellHeight: CGFloat = 56.0
        static let warningsButtonSize = CGSize(width: 44, height: 44)
    }

    weak var delegate: NetworkIssuesNotificationTableCellDelegate?

    private let containerView: TriangularedView = {
        let view = TriangularedView()
        view.strokeColor = R.color.colorWhite8()!
        view.highlightedStrokeColor = R.color.colorWhite8()!
        view.strokeWidth = 0.5
        view.fillColor = R.color.colorSemiBlack()!
        view.highlightedFillColor = R.color.colorSemiBlack()!
        view.shadowOpacity = 0
        return view
    }()

    private let chainImageView = UIImageView()
    private let chainNameLabel: UILabel = {
        let label = UILabel()
        label.font = .h6Title
        label.textColor = R.color.colorStrokeGray()
        return label
    }()

    private let issueDescriptionLabel: UILabel = {
        let label = UILabel()
        label.font = .p3Paragraph
        label.textColor = R.color.colorStrokeGray()
        return label
    }()

    private let actionButton: TriangularedButton = {
        let button = TriangularedButton()
        button.triangularedView?.sideLength = 6
        button.triangularedView?.shadowOpacity = 0
        button.imageWithTitleView?.titleFont = .p3Paragraph
        return button
    }()

    let warningButton: UIButton = {
        let button = UIButton()
        button.setImage(R.image.iconWarning(), for: .normal)
        return button
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        chainImageView.kf.cancelDownloadTask()
    }

    func bind(viewModel: NetworkIssuesNotificationCellViewModel) {
        viewModel.imageViewViewModel?.loadImage(
            on: chainImageView,
            targetSize: Constants.chainImageViewSize,
            animated: true
        )

        chainNameLabel.text = viewModel.chainNameTitle
        issueDescriptionLabel.text = viewModel.issueDescription

        switch viewModel.buttonType {
        case let .switchNode(title):
            configureSwitchNodeButton(with: title)
        case .networkUnavailible:
            conficureNetworkUnavailibleButton()
        case let .missingAccount(title):
            configureMissingAccounteButton(with: title)
        }
    }

    // MARK: - Private methods

    private func configureSwitchNodeButton(with title: String) {
        actionButton.isHidden = false
        warningButton.isHidden = true

        actionButton.imageWithTitleView?.title = title
        actionButton.triangularedView?.fillColor = R.color.colorPink()!
        actionButton.triangularedView?.highlightedFillColor = R.color.colorPink()!

        actionButton.addTarget(self, action: #selector(handleActionTap), for: .touchUpInside)
    }

    private func conficureNetworkUnavailibleButton() {
        actionButton.isHidden = true
        warningButton.isHidden = false

        actionButton.triangularedView?.fillColor = .clear
        actionButton.triangularedView?.highlightedFillColor = .clear

        warningButton.addTarget(self, action: #selector(handleActionTap), for: .touchUpInside)
    }

    private func configureMissingAccounteButton(with title: String) {
        actionButton.isHidden = false
        warningButton.isHidden = true

        actionButton.imageWithTitleView?.title = title
        actionButton.triangularedView?.fillColor = R.color.colorOrange()!
        actionButton.triangularedView?.highlightedFillColor = R.color.colorPink()!

        actionButton.invalidateIntrinsicContentSize()

        actionButton.addTarget(self, action: #selector(handleActionTap), for: .touchUpInside)
    }

    private func setupLayout() {
        backgroundColor = .clear
        contentView.addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.height.equalTo(Constants.cellHeight)
            make.top.equalToSuperview()
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview().inset(8)
        }

        containerView.addSubview(chainImageView)
        chainImageView.snp.makeConstraints { make in
            make.size.equalTo(Constants.chainImageViewSize)
            make.centerY.equalToSuperview()
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
        }

        let textVStackView = UIFactory.default.createVerticalStackView(spacing: 2)
        textVStackView.addArrangedSubview(chainNameLabel)
        textVStackView.addArrangedSubview(issueDescriptionLabel)

        containerView.addSubview(textVStackView)
        textVStackView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview().inset(13)
            make.leading.equalTo(chainImageView.snp.trailing).offset(UIConstants.accessoryItemsSpacing)
        }

        let actionsStackView = UIFactory.default.createHorizontalStackView()
        actionsStackView.alignment = .trailing
        containerView.addSubview(actionsStackView)
        actionsStackView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.greaterThanOrEqualTo(textVStackView.snp.trailing)
            make.trailing.equalToSuperview().inset(UIConstants.offset12)
            make.top.bottom.equalToSuperview().inset(UIConstants.bigOffset)
        }

        actionButton.snp.makeConstraints { make in
            make.size.greaterThanOrEqualTo(Constants.actionButtonSize)
        }
        warningButton.snp.makeConstraints { make in
            make.size.equalTo(Constants.warningsButtonSize)
        }

        actionsStackView.addArrangedSubview(actionButton)
        actionsStackView.addArrangedSubview(warningButton)
    }

    // MARK: - Actions

    @objc private func handleActionTap() {
        delegate?.didTapOnAction(with: indexPath)
    }
}
