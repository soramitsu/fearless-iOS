import Foundation
import UIKit
import SoraUI

protocol WalletsManagmentTableCellDelegate: AnyObject {
    func didTapOptionsCell(with indexPath: IndexPath?)
}

final class WalletsManagmentTableCell: UITableViewCell {
    private enum Constants {
        static let cellHeight: CGFloat = 72
        static let conentEdgeInstets = UIEdgeInsets(
            top: 8, left: 12, bottom: 8, right: 12
        )
        static let optionsButtonSize = CGSize(width: 44, height: 44)
    }

    private let backgroundTriangularedView: TriangularedView = {
        let view = TriangularedView()
        view.fillColor = R.color.colorSemiBlack()!
        view.highlightedFillColor = R.color.colorSemiBlack()!
        view.strokeColor = .clear
        view.highlightedStrokeColor = R.color.colorPink()!
        view.strokeWidth = 1
        view.shadowOpacity = 0
        view.gradientBorderColors = UIColor.walletBorderGradientColors
        return view
    }()

    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        return imageView
    }()

    private let walletNameLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textColor = R.color.colorStrokeGray()!
        return label
    }()

    private let fiatBalanceLabel: UILabel = {
        let label = UILabel()
        label.font = .h4Title
        return label
    }()

    private let dayChangeLabel: UILabel = {
        let label = UILabel()
        label.font = .p3Paragraph
        return label
    }()

    private let optionsButton: UIButton = {
        let button = UIButton()
        button.setImage(R.image.iconHorMore(), for: .normal)
        button.clipsToBounds = true
        button.isHidden = true
        return button
    }()

    private var skeletonView: SkrullableView?

    weak var delegate: WalletsManagmentTableCellDelegate? {
        didSet {
            optionsButton.isHidden = false
        }
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupLayout()
        configure()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(to viewModel: WalletsManagmentCellViewModel) {
        iconImageView.image = R.image.iconBirdGreen()
        walletNameLabel.text = viewModel.walletName
        dayChangeLabel.attributedText = viewModel.dayChange
        backgroundTriangularedView.setGradientBorder(highlighted: viewModel.isSelected, animated: false)

        fiatBalanceLabel.text = viewModel.fiatBalance

        if viewModel.fiatBalance == nil {
            startLoadingIfNeeded()
        } else {
            stopLoadingIfNeeded()
        }
    }

    private func configure() {
        optionsButton.addTarget(self, action: #selector(optionsDidTap), for: .touchUpInside)
    }

    @objc private func optionsDidTap() {
        delegate?.didTapOptionsCell(with: indexPath)
    }

    private func setupLayout() {
        selectionStyle = .none
        backgroundColor = .clear

        contentView.addSubview(backgroundTriangularedView)
        backgroundTriangularedView.snp.makeConstraints { make in
            make.edges.equalTo(Constants.conentEdgeInstets)
            make.height.equalTo(Constants.cellHeight)
        }

        backgroundTriangularedView.addSubview(iconImageView)
        iconImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(UIConstants.offset12)
            make.centerY.equalToSuperview()
            make.size.equalTo(UIConstants.normalAddressIconSize)
        }

        let vStackView = UIFactory.default.createVerticalStackView(spacing: UIConstants.minimalOffset)
        vStackView.distribution = .fillEqually
        backgroundTriangularedView.addSubview(vStackView)
        vStackView.snp.makeConstraints { make in
            make.leading.equalTo(iconImageView.snp.trailing).offset(UIConstants.offset12)
            make.top.bottom.equalToSuperview().inset(UIConstants.minimalOffset)
        }

        vStackView.addArrangedSubview(walletNameLabel)
        vStackView.addArrangedSubview(fiatBalanceLabel)
        vStackView.addArrangedSubview(dayChangeLabel)

        backgroundTriangularedView.addSubview(optionsButton)
        optionsButton.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.size.equalTo(Constants.optionsButtonSize)
            make.trailing.equalToSuperview()
            make.leading.equalTo(vStackView.snp.trailing).offset(UIConstants.defaultOffset)
        }
    }
}

extension WalletsManagmentTableCell: SkeletonLoadable {
    func didDisappearSkeleton() {
        skeletonView?.stopSkrulling()
    }

    func didAppearSkeleton() {
        skeletonView?.stopSkrulling()
        skeletonView?.startSkrulling()
    }

    func didUpdateSkeletonLayout() {
        guard let skeletonView = skeletonView else {
            return
        }

        if skeletonView.frame.size != frame.size {
            skeletonView.removeFromSuperview()
            self.skeletonView = nil
            setupSkeleton()
        }
    }

    func startLoadingIfNeeded() {
        guard skeletonView == nil else {
            return
        }

        fiatBalanceLabel.alpha = 0.0
        dayChangeLabel.alpha = 0.0

        setupSkeleton()
    }

    func stopLoadingIfNeeded() {
        guard skeletonView != nil else {
            return
        }

        skeletonView?.stopSkrulling()
        skeletonView?.removeFromSuperview()
        skeletonView = nil

        fiatBalanceLabel.alpha = 1.0
        dayChangeLabel.alpha = 1.0
    }

    private func setupSkeleton() {
        let spaceSize = CGSizeMake(frame.width - Constants.optionsButtonSize.width, frame.height)

        guard spaceSize != .zero else {
            self.skeletonView = Skrull(size: .zero, decorations: [], skeletons: []).build()
            return
        }

        let skeletonView = Skrull(
            size: spaceSize,
            decorations: [],
            skeletons: createSkeletons(for: spaceSize)
        )
        .fillSkeletonStart(R.color.colorSkeletonStart()!)
        .fillSkeletonEnd(color: R.color.colorSkeletonEnd()!)
        .build()

        self.skeletonView = skeletonView

        skeletonView.frame = CGRect(origin: .zero, size: spaceSize)
        skeletonView.autoresizingMask = []
        insertSubview(skeletonView, aboveSubview: contentView)

        skeletonView.startSkrulling()
    }

    private func createSkeletons(for spaceSize: CGSize) -> [Skeletonable] {
        let defaultBigWidth = 72.0
        let defaultHeight = 16.0
        let smallHeight = 10.0

        let titleWidth = fiatBalanceLabel.text?.widthOfString(usingFont: fiatBalanceLabel.font)
        let incomeWidth = dayChangeLabel.text?.widthOfString(usingFont: dayChangeLabel.font)

        let titleSize = CGSize(width: titleWidth ?? defaultBigWidth, height: defaultHeight)
        let incomeSize = CGSize(width: incomeWidth ?? defaultBigWidth, height: smallHeight)

        return [
            SingleSkeleton.createRow(
                spaceSize: spaceSize,
                position: CGPoint(x: UIConstants.offset12 + UIConstants.normalAddressIconSize.width + UIConstants.hugeOffset, y: spaceSize.height / 2),
                size: titleSize
            ),
            SingleSkeleton.createRow(
                spaceSize: spaceSize,
                position: CGPoint(x: UIConstants.offset12 + UIConstants.normalAddressIconSize.width + UIConstants.hugeOffset, y: spaceSize.height / 2 + defaultHeight / 2 + UIConstants.offset12),
                size: incomeSize
            )
        ]
    }
}
