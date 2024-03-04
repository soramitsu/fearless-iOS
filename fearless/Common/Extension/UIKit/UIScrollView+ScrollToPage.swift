import UIKit

extension UIScrollView {
    struct Page {
        enum Direction {
            case vertical(offset: CGFloat)
            case horizontal(offset: CGFloat)

            var offset: CGFloat {
                switch self {
                case let .vertical(offset), let .horizontal(offset):
                    return offset
                }
            }
        }

        let intValue: Int
        let direction: Direction
    }

    func scrollTo(
        horizontalPage: Page? = Page(intValue: 0, direction: .horizontal(offset: 0)),
        verticalPage: Page? = Page(intValue: 0, direction: .vertical(offset: 0)),
        animated: Bool? = true
    ) {
        var frame: CGRect = self.frame
        frame.origin.x = (frame.size.width + (horizontalPage?.direction.offset ?? 0)) * CGFloat(horizontalPage?.intValue ?? 0)
        frame.origin.y = (frame.size.height + (verticalPage?.direction.offset ?? 0)) * CGFloat(verticalPage?.intValue ?? 0)
        scrollRectToVisible(frame, animated: animated ?? true)
    }
}
