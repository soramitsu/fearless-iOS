import UIKit

extension UIImage {
    func invertedImage() -> UIImage? {
        guard let cgImage = self.cgImage else { return nil }
        let ciImage = CoreImage.CIImage(cgImage: cgImage)
        guard let filter = CIFilter(name: "CIColorInvert") else { return nil }
        filter.setDefaults()
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        let context = CIContext(options: nil)
        guard let outputImage = filter.outputImage else { return nil }
        guard let outputImageCopy = context.createCGImage(outputImage, from: outputImage.extent) else { return nil }
        return UIImage(cgImage: outputImageCopy, scale: scale, orientation: .up)
    }
}
