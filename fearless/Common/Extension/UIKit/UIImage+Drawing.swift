import UIKit

extension UIImage {
    public static func background(from color: UIColor,
                                  size: CGSize = CGSize(width: 1.0, height: 1.0),
                                  cornerRadius: CGFloat = 0.0,
                                  contentScale: CGFloat = 1.0) -> UIImage? {
        let rect = CGRect(origin: .zero, size: size)
        let bezierPath = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)

        UIGraphicsBeginImageContextWithOptions(size, false, contentScale)
        guard let context = UIGraphicsGetCurrentContext() else {
            return nil
        }

        context.setFillColor(color.cgColor)
        context.addPath(bezierPath.cgPath)
        context.fillPath()

        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return image
    }

    func crop(targetSize: CGSize, cornerRadius: CGFloat, contentScale: CGFloat) -> UIImage? {
        guard size.width > 0, size.height > 0 else {
            return nil
        }

        guard targetSize.width > 0, targetSize.height > 0 else {
            return nil
        }

        var drawingSize = CGSize(width: targetSize.width, height: targetSize.width * size.height / size.width)

        if drawingSize.height < targetSize.height {
            drawingSize.height = targetSize.height
            drawingSize.width = targetSize.height * size.width / size.height
        }

        UIGraphicsBeginImageContextWithOptions(targetSize, false, contentScale)
        guard let context = UIGraphicsGetCurrentContext() else {
            return nil
        }

        let contextRect = CGRect(origin: .zero, size: targetSize)

        let drawingOrigin = CGPoint(x: contextRect.midX - drawingSize.width / 2.0,
                                    y: contextRect.midY - drawingSize.height / 2.0)
        let drawingRect = CGRect(origin: drawingOrigin, size: drawingSize)

        let scaledCornerRadius = cornerRadius
        let bezierPath = UIBezierPath(roundedRect: contextRect, cornerRadius: scaledCornerRadius)
        context.addPath(bezierPath.cgPath)
        context.clip()

        draw(in: drawingRect)

        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return image
    }

    func tinted(with color: UIColor, opaque: Bool = false) -> UIImage? {
        let templateImage = withRenderingMode(.alwaysTemplate)

        UIGraphicsBeginImageContextWithOptions(size, false, scale)

        color.set()
        templateImage.draw(in: CGRect(origin: .zero, size: size))

        let tintedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return tintedImage
    }
}
