import UIKit

class DynamicCollectionView: UICollectionView {
    override func layoutSubviews() {
        super.layoutSubviews()
        if !__CGSizeEqualToSize(bounds.size, intrinsicContentSize) {
            invalidateIntrinsicContentSize()
        }
    }

    override var intrinsicContentSize: CGSize {
        var size = contentSize
        size.height += (contentInset.top + contentInset.bottom)
        size.width += (contentInset.left + contentInset.right)
        return size
    }
}

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
    let scrollView = UIScrollView()
    let contentView = UIView()

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

    let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = R.color.colorWhite()
        label.numberOfLines = 0
        return label
    }()

    let collectionView: DynamicCollectionView = {
        let collectionView = DynamicCollectionView(
            frame: .zero,
            collectionViewLayout: NftCollectionViewFlowLayout()
        )
        collectionView.isScrollEnabled = true
        return collectionView
    }()

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
        addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(navigationBar)
        navigationBar.set(.present)
        navigationBar.setCenterViews([navigationTitleLabel])
        contentView.addSubview(imageView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(collectionView)
        setupConstraints()
    }

    private func setupConstraints() {
        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.height.equalToSuperview()
        }
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalTo(self)
        }
        navigationBar.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
        }
        imageView.snp.makeConstraints { make in
            make.top.equalTo(navigationBar.snp.bottom)
            make.leading.equalToSuperview().offset(UIConstants.defaultOffset)
            make.trailing.equalToSuperview().inset(UIConstants.defaultOffset)
            make.height.equalTo(300)
        }
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(imageView.snp.bottom).offset(8)
            make.leading.trailing.equalTo(imageView)
        }
        collectionView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.top.equalTo(titleLabel.snp.bottom)
        }
    }

    func bind(viewModel: NftCollectionViewModel) {
        navigationTitleLabel.text = viewModel.collectionName
        if let collectionImage = viewModel.collectionImage {
            collectionImage.loadImage(on: imageView, targetSize: CGSize(
                width: UIScreen.main.bounds.width - UIConstants.defaultOffset * 2,
                height: UIScreen.main.bounds.width - UIConstants.defaultOffset * 2
            ), animated: true, cornerRadius: 0)
        } else {
            imageView.setGIFImage(name: "animatedIcon")
        }
        titleLabel.text = viewModel.collectionDescription
    }
}
