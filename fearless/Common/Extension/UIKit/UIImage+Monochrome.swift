import Foundation
import UIKit

extension UIImage {
    func monochrome() -> UIImage? {
        guard let currentCGImage = cgImage else { return nil }
        let currentCIImage = CIImage(cgImage: currentCGImage)

        let filter = CIFilter(name: "CIColorMonochrome")
        filter?.setValue(currentCIImage, forKey: "inputImage")

        // set a gray value for the tint color
        filter?.setValue(CIColor(red: 0.7, green: 0.7, blue: 0.7), forKey: "inputColor")

        filter?.setValue(1.0, forKey: "inputIntensity")
        guard let outputImage = filter?.outputImage else { return nil }

        let context = CIContext()

        guard let cgimg = context.createCGImage(outputImage, from: outputImage.extent) else {
            return nil
        }

        let processedImage = UIImage(cgImage: cgimg)
        return processedImage
    }
}
