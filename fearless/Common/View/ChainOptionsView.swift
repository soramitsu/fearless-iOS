import UIKit

class ChainOptionsView: UIView {
    enum LayoutConstants {
        static let corderRadius: CGFloat = 3
        static let iconSize = CGSize(width: 16, height: 16)
    }

    let imageView = UIImageView()

    let label: UILabel = {
        let label = UILabel()
        label.font = .capsTitle
        label.textColor = R.color.colorTransparentText()
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorWhite16()
        layer.cornerRadius = LayoutConstants.corderRadius
        layer.masksToBounds = true

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setupLayout() {
        addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(UIConstants.minimalOffset)
            make.centerY.equalToSuperview()
            make.size.equalTo(LayoutConstants.iconSize)
        }

        addSubview(label)
        label.snp.makeConstraints { make in
            make.leading.equalTo(imageView.snp.trailing).offset(UIConstants.minimalOffset)
            make.top.bottom.equalToSuperview()
            make.trailing.equalToSuperview().inset(UIConstants.minimalOffset)
        }
    }

    func bind(to viewModel: ChainOptionsViewModel) {
        label.text = viewModel.text.uppercased()
        viewModel.icon?.loadImage(
            on: imageView,
            targetSize: LayoutConstants.iconSize,
            animated: true
        )
    }
}
