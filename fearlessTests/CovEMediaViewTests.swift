@testable import fearless
import ImageIO
import UIKit
import XCTest

@MainActor
final class CovEMediaViewTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("CovEMedia-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
        try super.tearDownWithError()
    }

    func testImageFilesAreLoadedByExtensionAndBySniffingTheirBytes() throws {
        for name in ["picture.png", "picture.dat"] {
            let url = directory.appendingPathComponent(name)
            try pngData().write(to: url)
            let view = UniversalMediaView(frame: CGRect(x: 0, y: 0, width: 120, height: 120))
            let window = CovEHost.window(for: view, frame: view.frame)
            defer { CovEHost.close(window) }
            let indicator = try XCTUnwrap(CovEFind.mirror(view, "activityIndicator", as: UIActivityIndicatorView.self))
            XCTAssertTrue(indicator.isHidden, "the spinner stays hidden until something loads")

            view.bind(mediaURL: url, animating: false)
            XCTAssertTrue(indicator.isAnimating, "\(name): loading shows the spinner")
            XCTAssertTrue(CovEHost.spin(until: { view.image != nil && !indicator.isAnimating }, timeout: 10), name)
            XCTAssertEqual(view.image?.size, CGSize(width: 4, height: 4), name)
            XCTAssertEqual(media(of: view, "imageURL"), url.absoluteString, name)
        }
    }

    func testGifVideoThumbnailAndUnknownFilesStopTheSpinner() throws {
        let gif = directory.appendingPathComponent("loop.gif")
        try gifData().write(to: gif)
        let text = directory.appendingPathComponent("notes.bin")
        try Data("plain text, not media".utf8).write(to: text)
        let missingVideo = directory.appendingPathComponent("clip.mov")
        let missing = directory.appendingPathComponent("missing.dat")

        for (url, check) in [
            (gif, "gifURL"), (missingVideo, nil), (text, nil), (missing, nil)
        ] as [(URL, String?)] {
            let view = UniversalMediaView(frame: CGRect(x: 0, y: 0, width: 120, height: 120))
            let window = CovEHost.window(for: view, frame: view.frame)
            defer { CovEHost.close(window) }
            let indicator = try XCTUnwrap(CovEFind.mirror(view, "activityIndicator", as: UIActivityIndicatorView.self))
            view.bind(mediaURL: url, animating: false)
            XCTAssertTrue(indicator.isAnimating)
            XCTAssertTrue(CovEHost.spin(until: { !indicator.isAnimating }, timeout: 10), url.lastPathComponent)
            if let check {
                XCTAssertEqual(media(of: view, check), url.absoluteString)
            } else {
                XCTAssertNil(media(of: view, "gifURL"))
                XCTAssertNil(media(of: view, "videoURL"), "\(url.lastPathComponent) is not played")
            }
        }
    }

    func testAnimatedVideoKeepsTheSpinnerUntilThePlayIndicatorHides() throws {
        let video = directory.appendingPathComponent("clip.mp4")
        let view = UniversalMediaView(frame: CGRect(x: 0, y: 0, width: 120, height: 120))
        let window = CovEHost.window(for: view, frame: view.frame)
        defer { CovEHost.close(window) }
        let indicator = try XCTUnwrap(CovEFind.mirror(view, "activityIndicator", as: UIActivityIndicatorView.self))

        view.bind(mediaURL: nil, animating: true)
        XCTAssertFalse(indicator.isAnimating, "no URL leaves the view idle")

        view.bind(mediaURL: video, animating: true)
        XCTAssertTrue(CovEHost.spin(until: { self.media(of: view, "videoURL") != nil }, timeout: 10))
        XCTAssertEqual(media(of: view, "videoURL"), video.absoluteString)
        view.hidePlayIndicator(animated: false)
        XCTAssertFalse(indicator.isAnimating)
    }

    private func media(of view: UniversalMediaView, _ key: String) -> String? {
        guard let media = CovEFind.mirror(view, "media", as: AnyObject.self) else { return nil }
        return CovEFind.mirror(media, key, as: String.self)
    }

    private func pngData() -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4), format: {
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            return format
        }())
        return renderer.pngData { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        }
    }

    private func gifData() throws -> Data {
        let data = NSMutableData()
        let image = try XCTUnwrap(UIImage(data: pngData())?.cgImage)
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(data, "com.compuserve.gif" as CFString, 2, nil))
        // MediaView's GIF decoder reads a zero frame delay as a CFString and crashes on the NSNumber ImageIO returns
        // (reported as a bug), so the frames carry a real delay.
        let frame = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 0.1]] as CFDictionary
        CGImageDestinationAddImage(destination, image, frame)
        CGImageDestinationAddImage(destination, image, frame)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return data as Data
    }
}
