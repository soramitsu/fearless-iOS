import UIKit

extension UIScrollView {
    func scrollTo(horizontalPage: Int? = 0, verticalPage: Int? = 0, animated: Bool? = true, offset: CGFloat = 0) {
        var frame: CGRect = self.frame
        frame.origin.x = (frame.size.width + offset) * CGFloat(horizontalPage ?? 0)
        frame.origin.y = frame.size.height * CGFloat(verticalPage ?? 0)
        scrollRectToVisible(frame, animated: animated ?? true)
    }
}
