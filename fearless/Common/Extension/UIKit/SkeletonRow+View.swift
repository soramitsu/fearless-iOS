import Foundation
import SoraUI

extension SingleSkeleton {
    static func createRow(
        under targetView: UIView,
        containerView: UIView,
        spaceSize: CGSize,
        offset: CGPoint,
        size: CGSize
    ) -> SingleSkeleton {
        let targetFrame = targetView.convert(targetView.bounds, to: containerView)

        let position = CGPoint(
            x: targetFrame.minX + offset.x + size.width / 2.0,
            y: targetFrame.maxY + offset.y + size.height / 2.0
        )

        let mappedSize = CGSize(
            width: spaceSize.skrullMapX(size.width),
            height: spaceSize.skrullMapY(size.height)
        )

        return SingleSkeleton(position: spaceSize.skrullMap(point: position), size: mappedSize).round()
    }

    static func createRow(
        inPlaceOf targetView: UIView,
        containerView: UIView,
        spaceSize: CGSize,
        offset: CGPoint = .zero,
        size: CGSize
    ) -> SingleSkeleton {
        let targetFrame = targetView.convert(targetView.bounds, to: containerView)

        let position = CGPoint(
            x: targetFrame.minX + size.width / 2.0 + offset.x,
            y: targetFrame.midY + offset.y
        )

        let mappedSize = CGSize(
            width: spaceSize.skrullMapX(size.width),
            height: spaceSize.skrullMapY(size.height)
        )

        return SingleSkeleton(position: spaceSize.skrullMap(point: position), size: mappedSize).round()
    }

    static func createRow(
        containerView _: UIView,
        spaceSize: CGSize,
        position: CGPoint,
        size: CGSize
    ) -> SingleSkeleton {
        let position = CGPoint(
            x: position.x + size.width / 2,
            y: position.y
        )

        let mappedSize = CGSize(
            width: spaceSize.skrullMapX(size.width),
            height: spaceSize.skrullMapY(size.height)
        )

        return SingleSkeleton(position: spaceSize.skrullMap(point: position), size: mappedSize).round()
    }
}
