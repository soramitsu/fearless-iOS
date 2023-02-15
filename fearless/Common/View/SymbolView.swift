import Foundation
import UIKit

struct SymbolViewModel {
    let symbolViewModel: RemoteImageViewModel?
    let shadowColor: CGColor?
}

final class SymbolView: UIView {
    private enum Constants {
        static let imageViewSize = CGSize(width: 41, height: 41)
        static let imageViewInset: CGFloat = 18.0
        static let shadowRadius: CGFloat = 12
        static let shadowOpacity: Float = 0.5
    }

    private let containerView = UIView()
    private let imageView = UIImageView()

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
        containerView.layer.cornerRadius = containerView.frame.height / 2
    }

    func bind(viewModel: SymbolViewModel) {
        viewModel.symbolViewModel?.loadImage(
            on: imageView,
            targetSize: Constants.imageViewSize,
            animated: true
        )
        containerView.layer.shadowColor = viewModel.shadowColor
    }

    private func setupLayout() {
        containerView.backgroundColor = R.color.colorBlack()

        containerView.addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(Constants.imageViewInset)
            make.size.equalTo(Constants.imageViewSize)
        }

        containerView.layer.shadowRadius = Constants.shadowRadius
        containerView.layer.shadowOpacity = Constants.shadowOpacity

        addSubview(containerView)

        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}
