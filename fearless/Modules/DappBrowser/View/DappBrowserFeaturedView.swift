import UIKit

struct DappBrowserFeaturedViewModel {
    let poster: ImageViewModelProtocol
    let icon: ImageViewModelProtocol
    let dappName: String
    let dappDescription: String
    let dapp: TonDapp
}

final class DappBrowserFeaturedView: UIView {
    private enum Constants {
        static let numberOfAdditionalItems = 5
    }

    var didSelectApp: ((Int) -> Void)?

    private var dataSource = [DappBrowserFeaturedViewModel]()

    private lazy var collectionView = CollectionView(
        frame: .zero,
        collectionViewLayout: createLayout()
    )

    private var indexOfCellBeforeDragging = 0
    private var slideshowTask: Task<Void, Never>?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        collectionView.frame = bounds
    }

    override func didMoveToSuperview() {
        guard superview != nil else {
            stopSlideShow()
            return
        }
        startSlideShow()
    }

    func set(dataSource: [DappBrowserFeaturedViewModel]) {
        let dataSource = (0 ..< Constants.numberOfAdditionalItems)
            .reduce(into: [DappBrowserFeaturedViewModel]()) { partialResult, _ in
                partialResult = partialResult + dataSource
            }
        self.dataSource = dataSource

        collectionView.alpha = 0
        collectionView.reloadData()
        collectionView.layoutIfNeeded()
        guard !dataSource.isEmpty else { return }
        DispatchQueue.main.async {
            self.collectionView.scrollToItem(
                at: IndexPath(
                    item: 0,
                    section: 0
                ),
                at: .centeredHorizontally,
                animated: false
            )
            UIView.animate(withDuration: 0.2) {
                self.collectionView.alpha = 1.0
            }
            self.startSlideShowTask()
        }
    }

    // MARK: - Private methods

    private func setup() {
        collectionView.contentInsetAdjustmentBehavior = .never
        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.decelerationRate = .fast
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.registerClassForCell(DappBrowserFeaturedCell.self)

        addSubview(collectionView)
    }

    private func createLayout() -> UICollectionViewLayout {
        let configuration = UICollectionViewCompositionalLayoutConfiguration()
        configuration.scrollDirection = .horizontal

        let layout = UICollectionViewCompositionalLayout(sectionProvider: { _, environment -> NSCollectionLayoutSection? in
            let itemSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .absolute(environment.container.effectiveContentSize.height)
            )
            let item = NSCollectionLayoutItem(layoutSize: itemSize)

            let groupSize = NSCollectionLayoutSize(
                widthDimension: .absolute(environment.container.effectiveContentSize.width),
                heightDimension: .absolute(environment.container.effectiveContentSize.height)
            )

            let group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitems: [item])

            let section = NSCollectionLayoutSection(group: group)
            return section

        }, configuration: configuration)
        return layout
    }

    private func startSlideShow() {
        startSlideShowTask()
    }

    private func stopSlideShow() {
        slideshowTask?.cancel()
        slideshowTask = nil
    }

    private func indexOfMostVisibleCell() -> Int {
        let proportionalOffset = collectionView.contentOffset.x / collectionView.bounds.width
        guard !proportionalOffset.isNaN else {
            return 0
        }
        let index = Int(round(proportionalOffset))
        let numberOfItems = collectionView.numberOfItems(inSection: 0)
        let safeIndex = max(0, min(numberOfItems - 1, index))
        return safeIndex
    }

    private func startSlideShowTask() {
        slideshowTask?.cancel()
        slideshowTask = Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                resetCarouselIfNeeded()
                self.collectionView.isScrollEnabled = false
                UIView.animate(withDuration: 0.5) {
                    self.collectionView.scrollToItem(
                        at: IndexPath(item: self.indexOfMostVisibleCell() + 1, section: 0),
                        at: .centeredHorizontally,
                        animated: true
                    )
                } completion: { _ in
                    self.collectionView.isScrollEnabled = true
                    self.startSlideShowTask()
                }
            }
        }
    }

    private func resetCarouselIfNeeded() {
        let indexOfLeftSignificantCell = Constants.numberOfAdditionalItems / 2 * dataSource.count / Constants.numberOfAdditionalItems
        let indexOfRightSignificantCell = indexOfLeftSignificantCell + (dataSource.count - 1) / Constants.numberOfAdditionalItems

        if indexOfMostVisibleCell() == indexOfLeftSignificantCell - 1 {
            collectionView.scrollToItem(
                at: IndexPath(
                    item: indexOfRightSignificantCell,
                    section: 0
                ),
                at: .centeredHorizontally,
                animated: false
            )
        }

        if indexOfMostVisibleCell() == indexOfRightSignificantCell + 1 {
            collectionView.scrollToItem(
                at: IndexPath(
                    item: indexOfLeftSignificantCell,
                    section: 0
                ),
                at: .centeredHorizontally,
                animated: false
            )
        }
    }
}

extension DappBrowserFeaturedView: UICollectionViewDataSource {
    func collectionView(_: UICollectionView, numberOfItemsInSection _: Int) -> Int {
        dataSource.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: DappBrowserFeaturedCell.reuseIdentifier,
            for: indexPath
        )

        (cell as? DappBrowserFeaturedCell)?.configure(model: dataSource[indexPath.item])

        return cell
    }
}

extension DappBrowserFeaturedView: UICollectionViewDelegate {
    func collectionView(
        _: UICollectionView,
        didSelectItemAt indexPath: IndexPath
    ) {
        let dAppsCount = dataSource.count / Constants.numberOfAdditionalItems
        let index = indexPath.item - ((indexPath.item / dAppsCount) * dAppsCount)
        didSelectApp?(index)
    }

    func scrollViewWillBeginDragging(_: UIScrollView) {
        indexOfCellBeforeDragging = indexOfMostVisibleCell()
        slideshowTask?.cancel()
    }

    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        targetContentOffset.pointee = scrollView.contentOffset

        let indexOfMostVisibleCell = self.indexOfMostVisibleCell()
        let numberOfItems = collectionView.numberOfItems(inSection: 0)
        let swipeVelocityThreshold: CGFloat = 0.5
        let hasEnoughVelocityToSlideToTheNextCell = indexOfCellBeforeDragging + 1 < numberOfItems && velocity.x > swipeVelocityThreshold
        let hasEnoughVelocityToSlideToThePreviousCell = indexOfCellBeforeDragging - 1 >= 0 && velocity.x < -swipeVelocityThreshold
        let majorCellIsTheCellBeforeDragging = indexOfMostVisibleCell == indexOfCellBeforeDragging
        let didUseSwipeToSkipCell = majorCellIsTheCellBeforeDragging && (hasEnoughVelocityToSlideToTheNextCell || hasEnoughVelocityToSlideToThePreviousCell)

        if didUseSwipeToSkipCell {
            let snapToIndex = indexOfCellBeforeDragging + (hasEnoughVelocityToSlideToTheNextCell ? 1 : -1)
            let toValue = collectionView.bounds.width * CGFloat(snapToIndex)

            UIView.animate(
                withDuration: 0.5,
                delay: 0,
                usingSpringWithDamping: 1,
                initialSpringVelocity: velocity.x,
                options: .allowUserInteraction,
                animations: {
                    scrollView.contentOffset = CGPoint(x: toValue, y: 0)
                    scrollView.layoutIfNeeded()
                },
                completion: nil
            )

        } else {
            let indexPath = IndexPath(row: indexOfMostVisibleCell, section: 0)
            collectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: true)
        }
    }

    func scrollViewDidEndDecelerating(_: UIScrollView) {
        resetCarouselIfNeeded()
        startSlideShowTask()
    }
}

private class CollectionView: UICollectionView {
    private var _safeAreaInsets: UIEdgeInsets?
    override var safeAreaInsets: UIEdgeInsets {
        get { _safeAreaInsets ?? super.safeAreaInsets }
        set { _safeAreaInsets = newValue }
    }
}
