import UIKit
import SoraUI
import WebKit
import Kingfisher

class NftListCell: UITableViewCell {
    private var model: NftListCellModel?
    private enum LayoutConstants {
        static let imageSize: CGFloat = 64.0
    }

    let stackView: UIStackView = {
        let stackView = UIFactory.default.createVerticalStackView(spacing: UIConstants.minimalOffset)
        stackView.alignment = .top
        return stackView
    }()

    let cardView: TriangularedBlurView = {
        let view = TriangularedBlurView()
        return view
    }()

    let nftImageView = UIImageView()

    let verticalSeparatorView: UIView = {
        let view = UIView()
        view.backgroundColor = R.color.colorWhite16()
        return view
    }()

    let chainLabel: UILabel = {
        let label = UILabel()
        label.font = .h6Title
        label.textColor = R.color.colorWhite50()
        return label
    }()

    let nftNameLabel: UILabel = {
        let label = UILabel()
        label.font = .h3Title
        label.textColor = R.color.colorWhite()
        return label
    }()

    let collectionNameLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = R.color.colorWhite50()
        return label
    }()

    let detailsArrowImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = R.image.iconNftDetailsArrow()
        return imageView
    }()

    let nftCountLabel: InsettedLabel = {
        let label = InsettedLabel(insets: UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4))
        label.font = .h5Title
        label.textColor = R.color.colorWhite50()
        label.backgroundColor = R.color.colorWhite8()
        label.layer.cornerRadius = 6
        label.layer.masksToBounds = true
        return label
    }()

    private var skeletonView: SkrullableView?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        selectionStyle = .none
        backgroundColor = .clear
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        model?.imageViewModel?.cancel(on: nftImageView)
        nftImageView.image = nil
    }

    func bind(viewModel: NftListCellModel?) {
        model = viewModel

        if let viewModel = viewModel {
            stopLoadingIfNeeded()
            viewModel.imageViewModel?.loadImage(
                on: nftImageView,
                targetSize: CGSize(width: LayoutConstants.imageSize, height: LayoutConstants.imageSize),
                animated: true,
                cornerRadius: 8
            )

            chainLabel.text = viewModel.chainNameLabelText
            nftNameLabel.text = viewModel.nftNameLabelText
            collectionNameLabel.attributedText = viewModel.priceLabelAttributedText
            nftCountLabel.text = viewModel.nftCountLabelText
        } else {
            startLoadingIfNeeded()
        }
    }

    private func setupLayout() {
        contentView.addSubview(cardView)
        cardView.addSubview(nftImageView)
        cardView.addSubview(verticalSeparatorView)
        cardView.addSubview(stackView)
        cardView.addSubview(detailsArrowImageView)
        cardView.addSubview(nftCountLabel)

        stackView.addArrangedSubview(chainLabel)
        stackView.addArrangedSubview(nftNameLabel)
        stackView.addArrangedSubview(collectionNameLabel)

        setupConstraints()
    }

    private func setupConstraints() {
        cardView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.top.bottom.equalToSuperview().inset(UIConstants.minimalOffset)
        }

        nftImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(UIConstants.defaultOffset)
            make.centerY.equalToSuperview()
            make.top.equalToSuperview().inset(UIConstants.defaultOffset)
            make.size.equalTo(LayoutConstants.imageSize)
        }

        verticalSeparatorView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview().inset(UIConstants.defaultOffset)
            make.width.equalTo(1)
            make.leading.equalTo(nftImageView.snp.trailing).offset(UIConstants.defaultOffset)
        }

        detailsArrowImageView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(UIConstants.defaultOffset)
            make.leading.equalTo(nftCountLabel.snp.trailing).offset(UIConstants.minimalOffset)
            make.centerY.equalToSuperview()
            make.size.equalTo(16)
        }

        nftCountLabel.snp.makeConstraints { make in
            make.height.equalTo(22)
            make.centerY.equalToSuperview()
        }

        stackView.snp.makeConstraints { make in
            make.leading.equalTo(verticalSeparatorView.snp.trailing).offset(UIConstants.defaultOffset)
            make.trailing.equalTo(nftCountLabel.snp.leading).offset(UIConstants.defaultOffset)
            make.top.bottom.equalToSuperview().inset(UIConstants.defaultOffset)
        }

        collectionNameLabel.snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(15)
        }
    }
}

extension NftListCell: SkeletonLoadable {
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

        chainLabel.alpha = 0.0
        nftNameLabel.alpha = 0.0
        collectionNameLabel.alpha = 0.0
        nftImageView.alpha = 0.0

        setupSkeleton()
    }

    func stopLoadingIfNeeded() {
        guard skeletonView != nil else {
            return
        }

        skeletonView?.stopSkrulling()
        skeletonView?.removeFromSuperview()
        skeletonView = nil

        chainLabel.alpha = 1.0
        nftNameLabel.alpha = 1.0
        collectionNameLabel.alpha = 1.0
        nftImageView.alpha = 1.0
    }

    private func setupSkeleton() {
        let spaceSize = frame.size

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
        let defaultBigWidth = 100.0

        let nftNameWidth = nftNameLabel.text?.widthOfString(usingFont: nftNameLabel.font)
        let chainNameWidth = chainLabel.text?.widthOfString(usingFont: chainLabel.font)
        let collectionNameWidth = collectionNameLabel.text?.widthOfString(usingFont: collectionNameLabel.font)

        let nftNameSize = CGSize(width: nftNameWidth ?? defaultBigWidth, height: 14)
        let chainNameSize = CGSize(width: chainNameWidth ?? defaultBigWidth, height: 10)
        let collectionNameSize = CGSize(width: collectionNameWidth ?? defaultBigWidth, height: 12)

        let textOffset = UIConstants.bigOffset + UIConstants.defaultOffset + LayoutConstants.imageSize + UIConstants.defaultOffset * 2
        return [
            SingleSkeleton.createRow(
                spaceSize: spaceSize,
                position: CGPoint(x: UIConstants.bigOffset + UIConstants.defaultOffset, y: spaceSize.height / 2),
                size: CGSize(width: LayoutConstants.imageSize, height: LayoutConstants.imageSize)
            ),
            SingleSkeleton.createRow(
                spaceSize: spaceSize,
                position: CGPoint(x: textOffset, y: UIConstants.defaultOffset * 3),
                size: chainNameSize
            ),
            SingleSkeleton.createRow(
                spaceSize: spaceSize,
                position: CGPoint(x: textOffset, y: spaceSize.height / 2),
                size: nftNameSize
            ),
            SingleSkeleton.createRow(
                spaceSize: spaceSize,
                position: CGPoint(x: textOffset, y: spaceSize.height / 2 + collectionNameSize.height + UIConstants.defaultOffset * 2),
                size: collectionNameSize
            )
        ]
    }
}
