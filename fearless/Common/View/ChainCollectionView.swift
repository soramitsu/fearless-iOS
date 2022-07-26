import UIKit
import SnapKit

struct ChainCollectionViewModel {
    let maxImagesCount: Int
    let chainImages: [RemoteImageViewModel?]
}

final class ChainCollectionView: UIView, ShimmeredProtocol {
    private lazy var containerStack: UIStackView = {
        let view = UIStackView()
        view.axis = .horizontal
        view.distribution = .fillEqually
        return view
    }()

    private var viewModel: ChainCollectionViewModel?
    private var imageViews: [UIImageView] = []
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
        clear()
        setupImageViews()
    }

    func prepareForReuse() {
        clear()
    }

    func startShimmeringAnimation() {
        imageViews.forEach { imageView in
            imageView.startShimmeringAnimation()
        }
    }

    func stopShimmeringAnimation() {
        imageViews.forEach { imageView in
            imageView.stopShimmeringAnimation()
        }
    }

    func bind(viewModel: ChainCollectionViewModel) {
        clear()
        self.viewModel = viewModel
        setupImageViews()
    }

    private func clear() {
        imageViews = []
        containerStack.arrangedSubviews.forEach { subview in
            containerStack.removeArrangedSubview(subview)
        }
    }

    private func setupImageViews() {
        guard let viewModel = viewModel else {
            return
        }
        viewModel.chainImages.forEach { [weak self] imageViewModel in
            let imageView = UIImageView()
            imageView.snp.makeConstraints { make in
                make.size.equalTo(16)
            }
            imageView.contentMode = .scaleAspectFit
//            imageView.startShimmeringAnimation()
            imageViewModel?.loadAssetChainsIcon(on: imageView, animated: false)
            self?.imageViews.append(imageView)
        }
        let availableStackSubviewsCount = min(Int(frame.width / 16), viewModel.maxImagesCount)
        var availableImageViews = imageViews
        if availableStackSubviewsCount < viewModel.chainImages.count {
//            We should save place for label
            let availableImageViewsCount = Int(frame.width / 16) - 1
            let prefix: Int = min(availableImageViewsCount, viewModel.maxImagesCount)
            availableImageViews = Array(imageViews.prefix(prefix > 0 ? prefix : 0))
        }
        availableImageViews.forEach { imageView in
            containerStack.addArrangedSubview(imageView)
        }
        if availableStackSubviewsCount < viewModel.chainImages.count {
            moreLabel.text = "+\(viewModel.chainImages.count - availableStackSubviewsCount)"
            containerStack.addArrangedSubview(moreLabel)
        }
    }

    private func setupLayout() {
        addSubview(containerStack)
        containerStack.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}

extension ImageViewModelProtocol {
    func loadAssetChainsIcon(on imageView: UIImageView, animated _: Bool) {
        loadImage(on: imageView, targetSize: CGSize(width: 16.0, height: 16.0), animated: true, cornerRadius: 0)
    }
}
