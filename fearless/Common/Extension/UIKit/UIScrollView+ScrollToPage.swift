import UIKit

extension UIScrollView {
    func scrollTo(horizontalPage: Int? = 0, verticalPage: Int? = 0, animated: Bool? = true) {
        var frame: CGRect = self.frame
        frame.origin.x = frame.size.width * CGFloat(horizontalPage ?? 0)
        frame.origin.y = frame.size.height * CGFloat(verticalPage ?? 0)
        scrollRectToVisible(frame, animated: animated ?? true)
    }
}
