import UIKit
import SoraUI

class NftCollectionCell: UICollectionViewCell {
    private enum LayoutConstants {
        static let imageSize: CGFloat = 172.0
    }

    let imageView = UIImageView()

    let nftCountLabel: InsettedLabel = {
        let label = InsettedLabel(insets: UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4))
        label.font = .p1Paragraph
        label.textColor = R.color.colorWhite50()
        label.backgroundColor = R.color.colorBlurOverlay()
        label.layer.cornerRadius = 6
        label.layer.masksToBounds = true
        return label
    }()

    let chainNameLabel: UILabel = {
        let label = UILabel()
        label.font = .h6Title
        label.numberOfLines = 0
        label.textColor = R.color.colorWhite50()
        return label
    }()

    let collectionNameLabel: UILabel = {
        let label = UILabel()
        label.font = .h5Title
        label.numberOfLines = 0
        label.textColor = R.color.colorWhite()
        return label
    }()

    let infoStackView: UIStackView = UIFactory.default.createVerticalStackView()

    private var skeletonView: SkrullableView?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupSubviews()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        contentView.layer.cornerRadius = 12.0
        contentView.layer.borderWidth = 1.0
        contentView.layer.borderColor = R.color.colorWhite8()?.cgColor
    }

    private func setupSubviews() {
        contentView.addSubview(imageView)
        addSubview(nftCountLabel)
        addSubview(infoStackView)
        infoStackView.addArrangedSubview(chainNameLabel)
        infoStackView.addArrangedSubview(collectionNameLabel)

        setupConstraints()
    }

    private func setupConstraints() {
        imageView.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
            make.size.equalTo(LayoutConstants.imageSize)
        }

        nftCountLabel.snp.makeConstraints { make in
            make.top.equalTo(imageView).offset(UIConstants.minimalOffset)
            make.trailing.equalTo(imageView).inset(UIConstants.minimalOffset)
        }

        infoStackView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview().inset(UIConstants.defaultOffset)
            make.top.equalTo(imageView.snp.bottom).offset(UIConstants.defaultOffset)
        }
    }

    func bind(cellModel: NftListCellModel?) {
        if let cellModel = cellModel {
            stopLoadingIfNeeded()
            if let imageViewModel = cellModel.imageViewModel {
                imageViewModel.loadImage(on: imageView, targetSize: CGSize(width: LayoutConstants.imageSize, height: LayoutConstants.imageSize), animated: true, cornerRadius: 0)
            } else {
                imageView.image = R.image.nftStub()
            }
            if let currentCount = cellModel.currentCount,
               let availableCount = cellModel.availableCount {
                nftCountLabel.text = "\(currentCount)/\(availableCount)"
                nftCountLabel.isHidden = false
            } else {
                nftCountLabel.isHidden = true
            }

            chainNameLabel.text = cellModel.collection.chain.name
            collectionNameLabel.text = cellModel.collection.name
        } else {
            startLoadingIfNeeded()
        }
    }
}

extension NftCollectionCell: SkeletonLoadable {
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

        chainNameLabel.alpha = 0.0
        collectionNameLabel.alpha = 0.0
        imageView.alpha = 0.0
        nftCountLabel.alpha = 0.0

        setupSkeleton()
    }

    func stopLoadingIfNeeded() {
        guard skeletonView != nil else {
            return
        }

        skeletonView?.stopSkrulling()
        skeletonView?.removeFromSuperview()
        skeletonView = nil

        chainNameLabel.alpha = 1.0
        collectionNameLabel.alpha = 1.0
        imageView.alpha = 1.0
        nftCountLabel.alpha = 1.0
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
        let defaultBigWidth: CGFloat = 100.0

        let labelMaxWidth = frame.size.width - UIConstants.defaultOffset * 2
        let chainNameWidth = chainNameLabel.text?.widthOfString(usingFont: chainNameLabel.font) ?? defaultBigWidth
        let collectionNameWidth = collectionNameLabel.text?.widthOfString(usingFont: collectionNameLabel.font) ?? defaultBigWidth
        let chainNameSize = CGSize(width: min(chainNameWidth, labelMaxWidth), height: 10)
        let collectionNameSize = CGSize(width: min(collectionNameWidth, labelMaxWidth), height: 12)

        return [
            SingleSkeleton.createRow(
                spaceSize: spaceSize,
                position: CGPoint(x: UIConstants.defaultOffset, y: LayoutConstants.imageSize / 2 + UIConstants.defaultOffset),
                size: CGSize(
                    width: LayoutConstants.imageSize - UIConstants.defaultOffset * 2,
                    height: LayoutConstants.imageSize - UIConstants.defaultOffset * 2
                )
            ),
            SingleSkeleton.createRow(
                spaceSize: spaceSize,
                position: CGPoint(x: UIConstants.defaultOffset, y: LayoutConstants.imageSize + UIConstants.defaultOffset + chainNameSize.height / 2),
                size: chainNameSize
            ),
            SingleSkeleton.createRow(
                spaceSize: spaceSize,
                position: CGPoint(x: UIConstants.defaultOffset, y: LayoutConstants.imageSize + UIConstants.defaultOffset * 2 + chainNameSize.height + collectionNameSize.height / 2),
                size: collectionNameSize
            )
        ]
    }
}
