import UIKit

final class StakingPoolMainViewLayout: UIView {
    private enum Constants {
        static let verticalSpacing: CGFloat = 0.0
        static let bottomInset: CGFloat = 8.0
        static let contentInset = UIEdgeInsets(
            top: UIConstants.bigOffset,
            left: 0,
            bottom: UIConstants.bigOffset,
            right: 0
        )
    }

    let contentView: ScrollableContainerView = {
        let view = ScrollableContainerView()
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.layoutMargins = UIEdgeInsets(top: 24.0, left: 0.0, bottom: 0.0, right: 0.0)
        return view
    }()

    let backgroundImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = R.image.backgroundImage()
        return imageView
    }()

    let assetSelectionContainerView = UIView()
    let assetSelectionView: DetailsTriangularedView = {
        let view = UIFactory.default.createChainAssetSelectionView()
        view.borderWidth = 0.0
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(backgroundImageView)
        backgroundImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        assetSelectionContainerView.translatesAutoresizingMaskIntoConstraints = false

        let backgroundView = TriangularedBlurView()
        assetSelectionContainerView.addSubview(backgroundView)
        assetSelectionContainerView.addSubview(assetSelectionView)

        applyConstraints(for: assetSelectionContainerView, innerView: assetSelectionView)

        contentView.stackView.addArrangedSubview(assetSelectionContainerView)

        assetSelectionView.snp.makeConstraints { make in
            make.height.equalTo(48.0)
        }

        backgroundView.snp.makeConstraints { make in
            make.edges.equalTo(assetSelectionView)
        }

        assetSelectionContainerView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
        }
    }

    private func applyConstraints(for containerView: UIView, innerView: UIView) {
        innerView.translatesAutoresizingMaskIntoConstraints = false
        innerView.leadingAnchor.constraint(
            equalTo: containerView.leadingAnchor,
            constant: UIConstants.horizontalInset
        ).isActive = true
        innerView.trailingAnchor.constraint(
            equalTo: containerView.trailingAnchor,
            constant: -UIConstants.horizontalInset
        ).isActive = true
        innerView.topAnchor.constraint(
            equalTo: containerView.topAnchor,
            constant: Constants.verticalSpacing
        ).isActive = true

        containerView.bottomAnchor.constraint(
            equalTo: innerView.bottomAnchor,
            constant: Constants.bottomInset
        ).isActive = true
    }

    func bind(chainAsset: ChainAsset) {
        if let iconUrl = chainAsset.chain.icon {
            let assetIconViewModel: ImageViewModelProtocol? = RemoteImageViewModel(url: iconUrl)
            assetIconViewModel?.cancel(on: assetSelectionView.iconView)

            let iconSize = 2 * assetSelectionView.iconRadius
            assetIconViewModel?.loadImage(
                on: assetSelectionView.iconView,
                targetSize: CGSize(width: iconSize, height: iconSize),
                animated: false
            )
        }

        assetSelectionView.title = chainAsset.asset.name
        assetSelectionView.iconImage = nil
    }

    func bind(balanceViewModel: BalanceViewModelProtocol) {
        assetSelectionView.subtitle = balanceViewModel.amount
    }
}
