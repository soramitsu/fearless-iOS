import Foundation
import UIKit

final class DefaultFlowLayout: UICollectionViewFlowLayout {
    // MARK: - Constants

    private enum Constants {
        static let spacing: CGFloat = 16
    }

    // MARK: - Private Properties

    private var contentOffset: CGPoint = .zero

    private var currentContentOffset: CGPoint {
        collectionView?.contentOffset ?? .zero
    }

    private var bounds: CGRect {
        collectionView?.bounds ?? .zero
    }

    private var numberOfItems: Int {
        collectionView?.numberOfItems(inSection: 0) ?? 0
    }

    // MARK: - UICollectionViewFlowLayout

    override func prepare() {
        super.prepare()
        configure()
    }

    override func targetContentOffset(
        forProposedContentOffset proposedContentOffset: CGPoint,
        withScrollingVelocity _: CGPoint
    ) -> CGPoint {
        let proposedRect = CGRect(
            x: proposedContentOffset.x,
            y: 0,
            width: bounds.width,
            height: bounds.height
        )

        guard let layoutAttributes = super.layoutAttributesForElements(in: proposedRect) else {
            return .zero
        }

        // find nearest cell
        var offset = CGFloat.greatestFiniteMagnitude
        var targetIndex = 0
        let horizontalCenter = proposedContentOffset.x + bounds.width / 2
        for attributes in layoutAttributes {
            if (attributes.center.x - horizontalCenter).magnitude < offset.magnitude {
                offset = attributes.center.x - horizontalCenter
                targetIndex = attributes.indexPath.item
            }
        }

        let targetContentOffset = getContentOffset(for: targetIndex)
        guard targetContentOffset != contentOffset else {
            DispatchQueue.main.async {
                self.collectionView?.setContentOffset(targetContentOffset, animated: true)
            }
            return currentContentOffset
        }

        contentOffset = targetContentOffset
        return targetContentOffset
    }

    // MARK: - Private Methods

    private func configure() {
        scrollDirection = .horizontal
        minimumLineSpacing = Constants.spacing
        configureItemSize()
    }

    private func configureItemSize() {
        let width: CGFloat = bounds.width
        let height = bounds.height
        itemSize = CGSize(width: width, height: height)
    }

    private func getContentOffset(for itemIndex: Int) -> CGPoint {
        var offsetX = (itemSize.width + Constants.spacing) * CGFloat(itemIndex)

        return CGPoint(x: offsetX, y: 0)
    }
}
