import ImageIO
import UIKit
import UniformTypeIdentifiers
import XCTest
@testable import fearless

/// The MediaView pod reads each GIF frame's delay as text and crashes (`-[__NSCFNumber length]`) on a frame whose
/// delay is zero. The pod is not part of this repository, so the app checks a GIF before handing it over and shows a
/// GIF the pod cannot decode as a still image.
final class UniversalMediaViewGIFTests: XCTestCase {
    func testGIFWithAZeroDelayFrameIsShownAsAStillImage() throws {
        let gif = try Self.gif(delays: [0.1, 0, 0.1])
        XCTAssertFalse(MediaViewGIFCompatibility.canDecode(gif))

        let view = UniversalMediaView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        view.showGIF(data: gif, url: URL(string: "https://example.com/zero-delay.gif")!)
        // The pod decodes on a later main-queue turn; let it run inside this test.
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))

        let image = try XCTUnwrap(view.image, "the first frame is shown")
        XCTAssertNil(image.images, "a still image, not the pod's animation")
    }

    func testGIFWithDelaysOnEveryFrameIsDecodable() throws {
        XCTAssertTrue(MediaViewGIFCompatibility.canDecode(try Self.gif(delays: [0.1, 0.2])))
    }

    func testDataThatIsNotAGIFIsNotHandedToThePod() {
        XCTAssertFalse(MediaViewGIFCompatibility.canDecode(Data("not a gif".utf8)))
    }

    private static func gif(delays: [Double]) throws -> Data {
        let data = NSMutableData()
        let destination = try XCTUnwrap(
            CGImageDestinationCreateWithData(data, UTType.gif.identifier as CFString, delays.count, nil)
        )
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4))
        for (index, delay) in delays.enumerated() {
            let frame = renderer.image { context in
                (index.isMultiple(of: 2) ? UIColor.red : UIColor.blue).setFill()
                context.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
            }
            let properties = [
                kCGImagePropertyGIFDictionary: [
                    kCGImagePropertyGIFDelayTime: delay,
                    kCGImagePropertyGIFUnclampedDelayTime: delay
                ]
            ] as CFDictionary
            CGImageDestinationAddImage(destination, try XCTUnwrap(frame.cgImage), properties)
        }
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return data as Data
    }
}
