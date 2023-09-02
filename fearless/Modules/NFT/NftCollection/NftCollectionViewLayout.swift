import UIKit

final class NftCollectionViewFlowLayout: UICollectionViewFlowLayout {
    override init() {
        super.init()
        sectionInset = UIEdgeInsets(
            top: UIConstants.bigOffset,
            left: UIConstants.bigOffset,
            bottom: 0,
            right: UIConstants.bigOffset
        )
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class NftCollectionViewLayout: UIView {
    let navigationBar: BaseNavigationBar = {
        let view = BaseNavigationBar()
        view.backgroundColor = R.color.colorBlack19()
        return view
    }()

    let navigationTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .h4Title
        label.textColor = R.color.colorWhite()
        return label
    }()

    let collectionView = UICollectionView(
        frame: .zero,
        collectionViewLayout: NftCollectionViewFlowLayout()
    )

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = R.color.colorBlack19()
        collectionView.backgroundColor = R.color.colorBlack19()
        setupSubviews()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupSubviews() {
        addSubview(navigationBar)
        navigationBar.set(.push)
        navigationBar.setCenterViews([navigationTitleLabel])
        addSubview(collectionView)
        setupConstraints()
    }

    private func setupConstraints() {
        navigationBar.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
        }
        collectionView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.top.equalTo(navigationBar.snp.bottom)
        }
    }

    func bind(viewModel: NftCollectionViewModel) {
        navigationTitleLabel.text = viewModel.collectionName
    }
}
