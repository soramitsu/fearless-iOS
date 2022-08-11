import UIKit
import SnapKit

struct ChainCollectionViewModel {
    let maxImagesCount: Int
    let chainImages: [RemoteImageViewModel?]
}

final class ChainCollectionView: UIView, ShimmeredProtocol {
    private enum Constants {
        static let elementSize: CGFloat = 16
        static let elementsSpacing: CGFloat = 2
    }

    private var containerView = UIView()

    private var viewModel: ChainCollectionViewModel?
    private let moreLabel: UILabel = {
        let label = UILabel()
        label.font = .capsTitle
        label.textColor = R.color.colorAlmostWhite()
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        setupImageViews()
    }

    func bind(viewModel: ChainCollectionViewModel) {
        self.viewModel = viewModel
        layoutSubviews()
    }

    private func clear() {
        containerView.subviews.forEach { subview in
            if let imageView = subview as? UIImageView {
                imageView.kf.cancelDownloadTask()
            }
            subview.removeFromSuperview()
        }
    }

    private func setupImageViews() {
        clear()
        guard let viewModel = viewModel else {
            return
        }
        var imageViews: [UIImageView] = []
        viewModel.chainImages.forEach { imageViewModel in
            let imageView = UIImageView()
            imageView.contentMode = .scaleAspectFit
            imageViewModel?.loadAssetChainsIcon(on: imageView, animated: false)
            imageViews.append(imageView)
        }
        let availableStackSubviewsCount = min(
            Int(frame.width / (Constants.elementSize + Constants.elementsSpacing)),
            viewModel.maxImagesCount
        )
        var availableImageViews = imageViews
        if availableStackSubviewsCount < viewModel.chainImages.count {
//            We should save place for label
            let availableImageViewsCount = Int(
                frame.width / (Constants.elementSize + Constants.elementsSpacing)
            ) - 1
            let prefix: Int = min(availableImageViewsCount, viewModel.maxImagesCount)
            availableImageViews = Array(imageViews.prefix(prefix > 0 ? prefix : 0))
        }
        if availableImageViews.count < imageViews.count {
            moreLabel.frame = CGRect(
                x: frame.width - Constants.elementSize,
                y: 0,
                width: Constants.elementSize,
                height: Constants.elementSize
            )
            moreLabel.text = "+\(viewModel.chainImages.count - availableStackSubviewsCount)"
            containerView.addSubview(moreLabel)
        }
        availableImageViews.forEach { imageView in
            let xPosition = frame.width - CGFloat(containerView.subviews.count + 1) * (Constants.elementSize + Constants.elementsSpacing)
            imageView.frame = CGRect(
                x: xPosition,
                y: 0,
                width: Constants.elementSize,
                height: Constants.elementSize
            )
            containerView.addSubview(imageView)
        }
    }

    private func setupLayout() {
        addSubview(containerView)
        containerView.frame = frame
    }
}

private extension ImageViewModelProtocol {
    func loadAssetChainsIcon(on imageView: UIImageView, animated: Bool) {
        loadImage(
            on: imageView,
            targetSize: CGSize(width: 16.0, height: 16.0),
            animated: animated,
            cornerRadius: 0
        )
    }
}
