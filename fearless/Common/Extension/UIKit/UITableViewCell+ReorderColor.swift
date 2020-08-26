import UIKit

extension UITableViewCell {
    /**
      * Didn't find other way to customize the reorder control
      * without reimplementing the whole dragging logic
     */
    func recolorReoderControl(_ newColor: UIColor) {
        var reorderImage: UIImage?
        for subViewA in subviews {
            if subViewA.classForCoder.description() == "UITableViewCellReorderControl" {
                for subViewB in subViewA.subviews {
                    if subViewB.isKind(of: UIImageView.classForCoder()) {
                        let imageView = subViewB as? UIImageView
                        if reorderImage == nil {
                            let currentImage = imageView?.image
                            reorderImage = currentImage?
                                .withRenderingMode(UIImage.RenderingMode.alwaysTemplate)
                        }
                        imageView?.image = reorderImage
                        imageView?.tintColor = newColor
                        break
                    }
                }
                break
            }
        }
    }
}
