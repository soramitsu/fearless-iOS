import UIKit

class TokenPairIconsView: UIView {
    let firstTokenIconView = UIImageView()
    let secondTokenIconView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        drawSubviews()
        setupLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        setupLayout()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)

        drawSubviews()
        setupLayout()
    }

    func bind(viewModel: TokenPairsIconViewModel) {
        let iconSize = CGSize(width: frame.size.height / 1.5, height: frame.size.height / 1.5)

        viewModel.firstTokenIconViewModel?.loadImage(on: firstTokenIconView, targetSize: iconSize, animated: false)
        viewModel.secondTokenIconViewModel?.loadImage(on: secondTokenIconView, targetSize: iconSize, animated: false)
    }

    private func drawSubviews() {
        addSubview(firstTokenIconView)
        addSubview(secondTokenIconView)
    }

    private func setupLayout() {
        let iconSize = frame.size.height / 1.5
        let horizontalOffset: CGFloat = -(iconSize / 3.0)
        let verticalOffset: CGFloat = -(iconSize / 2.0)
        firstTokenIconView.frame = CGRect(x: 0.0, y: 0.0, width: iconSize, height: iconSize)
        secondTokenIconView.frame = CGRect(
            x: CGRectGetMaxX(firstTokenIconView.frame) + horizontalOffset,
            y: CGRectGetMaxY(firstTokenIconView.frame) + verticalOffset,
            width: iconSize,
            height: iconSize
        )
    }
}
