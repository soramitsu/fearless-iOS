import UIKit

final class BannersViewLayout: UIView {
    var locale: Locale = .current {
        didSet {
            applyLocalization()
        }
    }

    let collectionView: UICollectionView = {
        let view = UICollectionView(frame: .zero, collectionViewLayout: DefaultFlowLayout())
        view.showsVerticalScrollIndicator = false
        view.showsHorizontalScrollIndicator = false
        view.backgroundColor = .clear
        view.decelerationRate = .fast
        view.registerClassForCell(BannerCollectionViewCell.self)
        return view
    }()

    let pageControl: UIPageControl = {
        let view = UIPageControl()
        view.pageIndicatorTintColor = R.color.colorWhite8()
        view.currentPageIndicatorTintColor = R.color.colorWhite50()
        view.isUserInteractionEnabled = false
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

    func setPageControl(pageCount: Int) {
        switch pageCount {
        case 0:
            pageControl.isHidden = true
            collectionView.isHidden = true
        case 1:
            pageControl.isHidden = true
            collectionView.isHidden = false
        default:
            pageControl.numberOfPages = pageCount
            pageControl.isHidden = false
            collectionView.isHidden = false
        }
    }

    // MARK: - Private methods

    private func setupLayout() {
        let stackContainer = UIFactory.default.createVerticalStackView(spacing: UIConstants.minimalOffset)
        addSubview(stackContainer)
        stackContainer.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        stackContainer.addArrangedSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(140)
        }

        stackContainer.addArrangedSubview(pageControl)
        pageControl.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
        }
    }

    private func applyLocalization() {}
}
