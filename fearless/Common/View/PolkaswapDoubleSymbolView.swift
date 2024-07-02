import Foundation
import UIKit

struct PolkaswapDoubleSymbolViewModel {
    let leftViewModel: RemoteImageViewModel?
    let rightViewModel: RemoteImageViewModel?
    let leftShadowColor: CGColor?
    let rightShadowColor: CGColor?
}

enum PolkaswapDoubleSymbolViewMode {
    case filled
    case centered
}

final class PolkaswapDoubleSymbolView: UIView {
    private enum Constants {
        static let imageViewSize = CGSize(width: 41, height: 41)
        static let imageViewInset: CGFloat = 18.0
        static let imagesInset: CGFloat = 22.0
        static let shadowRadius: CGFloat = 12
        static let shadowOpacity: Float = 0.5
    }

    private let leftContainer = UIView()
    private let rightContainer = UIView()
    private let leftImageView = UIImageView()
    private let rightImageView = UIImageView()

    private var imageSize: CGSize?
    private var mode: PolkaswapDoubleSymbolViewMode = .centered

    init(imageSize: CGSize?, mode: PolkaswapDoubleSymbolViewMode) {
        self.imageSize = imageSize
        self.mode = mode
        super.init(frame: .zero)
        setupLayout()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        leftContainer.layer.cornerRadius = leftContainer.frame.height / 2
        rightContainer.layer.cornerRadius = rightContainer.frame.height / 2
    }

    func bind(viewModel: PolkaswapDoubleSymbolViewModel) {
        let size = imageSize ?? Constants.imageViewSize
        viewModel.rightViewModel?.loadImage(
            on: rightImageView,
            targetSize: size,
            animated: true
        )
        viewModel.leftViewModel?.loadImage(
            on: leftImageView,
            targetSize: size,
            animated: true
        )
        leftContainer.layer.shadowColor = viewModel.leftShadowColor
        rightContainer.layer.shadowColor = viewModel.rightShadowColor
    }

    private func setupLayout() {
        let size = imageSize ?? Constants.imageViewSize

        addSubview(rightContainer)
        addSubview(leftContainer)

        leftContainer.addSubview(leftImageView)
        rightContainer.addSubview(rightImageView)

        switch mode {
        case .filled:
            leftImageView.snp.makeConstraints { make in
                make.edges.equalToSuperview()
                make.size.equalTo(size)
            }

            rightImageView.snp.makeConstraints { make in
                make.edges.equalToSuperview()
                make.size.equalTo(size)
            }
        case .centered:
            leftContainer.backgroundColor = R.color.colorBlack()
            rightContainer.backgroundColor = R.color.colorBlack()

            leftImageView.snp.makeConstraints { make in
                make.edges.equalToSuperview().inset(Constants.imageViewInset)
                make.size.equalTo(size)
            }

            rightImageView.snp.makeConstraints { make in
                make.edges.equalToSuperview().inset(Constants.imageViewInset)
                make.size.equalTo(size)
            }
        }

        [leftContainer, rightContainer].forEach { view in
            view.layer.shadowRadius = Constants.shadowRadius
            view.layer.shadowOpacity = Constants.shadowOpacity
        }

        leftContainer.snp.makeConstraints { make in
            make.top.leading.bottom.equalToSuperview()
            make.trailing.equalTo(rightContainer.snp.leading).offset(Constants.imagesInset)
        }

        rightContainer.snp.makeConstraints { make in
            make.top.trailing.bottom.equalToSuperview()
        }
    }
}
