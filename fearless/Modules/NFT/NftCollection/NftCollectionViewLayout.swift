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

    let imageView = UIImageView()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = R.color.colorWhite()
        label.numberOfLines = 0
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
        navigationBar.set(.present)
        navigationBar.setCenterViews([navigationTitleLabel])
        addSubview(imageView)
        addSubview(titleLabel)
        addSubview(collectionView)
        setupConstraints()
    }

    private func setupConstraints() {
        navigationBar.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
        }
        imageView.snp.makeConstraints { make in
            make.top.equalTo(navigationBar.snp.bottom)
            make.leading.equalToSuperview().offset(UIConstants.defaultOffset)
            make.trailing.equalToSuperview().inset(UIConstants.defaultOffset)
            make.height.equalTo(imageView.snp.width)
        }
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(imageView.snp.bottom)
            make.leading.trailing.equalTo(imageView)
        }
        collectionView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.top.equalTo(titleLabel.snp.bottom)
        }
    }

    func bind(viewModel: NftCollectionViewModel) {
        navigationTitleLabel.text = viewModel.collectionName
        viewModel.collectionImage?.loadImage(on: imageView, targetSize: CGSize(
            width: UIScreen.main.bounds.width - UIConstants.defaultOffset * 2,
            height: UIScreen.main.bounds.width - UIConstants.defaultOffset * 2
        ), animated: true, cornerRadius: 0)
        titleLabel.text = viewModel.collectionDescription
    }
}
