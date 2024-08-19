import UIKit

final class MultichainAssetSelectionViewLayout: UIView {
    let topBar = BaseNavigationBar()
    let chainsCollectionView: UICollectionView = {
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewLayout())
        collectionView.backgroundColor = .clear
        return collectionView
    }()

    let selectAssetContainerView = UIView()

    var locale: Locale = .current {
        didSet {
            applyLocalization()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        topBar.set(.present)
        addSubviews()
        setupConstraints()
        backgroundColor = R.color.colorBlack19()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func addSelectAssetView(_ view: UIView) {
        selectAssetContainerView.addSubview(view)
        view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    // MARK: - Private methods

    private func addSubviews() {
        addSubview(topBar)
        addSubview(chainsCollectionView)
        addSubview(selectAssetContainerView)
    }

    private func setupConstraints() {
        topBar.snp.makeConstraints { make in
            make.leading.trailing.top.equalToSuperview()
        }

        chainsCollectionView.snp.makeConstraints { make in
            make.top.equalTo(topBar.snp.bottom)
            make.leading.trailing.equalToSuperview().inset(16)
            make.height.equalTo(72)
        }

        selectAssetContainerView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.top.equalTo(chainsCollectionView.snp.bottom)
        }
    }

    private func applyLocalization() {
        topBar.setTitle("Select token")
    }
}
