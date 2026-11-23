import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI

/// QR generation with Core Image.
public enum QRCode {
    /// One pixel per module, black on white, including the generator's
    /// one-module margin. Nil for an empty payload.
    public static func image(for payload: String) -> CGImage? {
        guard !payload.isEmpty, let data = payload.data(using: .utf8) else { return nil }
        let filter = CIFilter.qrCodeGenerator()
        filter.message = data
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let context = CIContext(options: [.useSoftwareRenderer: true])
        return context.createCGImage(output, from: output.extent)
    }

    /// Number of modules along one side of the generated image.
    public static func moduleCount(for payload: String) -> Int? {
        image(for: payload)?.width
    }
}

/// A QR code that stays crisp at any size: modules are scaled without
/// smoothing. It is always dark on a white card with a quiet zone, so it
/// scans in light and dark appearance.
public struct QRCodeView: View {
    private let payload: String
    private let image: CGImage?

    public init(_ payload: String) {
        self.payload = payload
        self.image = QRCode.image(for: payload)
    }

    public var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                RoundedRectangle(cornerRadius: side * 0.06, style: .continuous)
                    .fill(.white)
                if let image {
                    Image(decorative: image, scale: 1)
                        .interpolation(.none)
                        .resizable()
                        .aspectRatio(1, contentMode: .fit)
                        .padding(side * 0.07)
                } else {
                    Image(systemName: "qrcode")
                        .font(.system(size: side * 0.4))
                        .foregroundStyle(.gray)
                }
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel("QR code of the address")
        .accessibilityAddTraits(.isImage)
    }
}
