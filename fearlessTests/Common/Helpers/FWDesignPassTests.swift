@testable import fearless
import UIKit
import XCTest

/// Brand kit v3 design pass: the wallet total's count and the sky card's text contrast.
final class FWCountUpTests: XCTestCase {
    func testTheCountKeepsAffixesMarksAndFractionDigits() throws {
        let cases: [(String, String)] = [
            ("$0.0906597", "$0.0000000"),
            ("$1,234.56", "$0.00"),
            ("1.234,56 €", "0,00 €"),
            ("¥1,234,567", "¥0"),
            ("12 345,67 ₽", "0,00 ₽")
        ]
        for (final, zero) in cases {
            let run = try XCTUnwrap(FWCountUp.Run(final: final), final)
            XCTAssertEqual(run.text(progress: 0), zero, final)
            XCTAssertEqual(run.text(progress: 1), final, final)
            XCTAssertEqual(run.text(at: run.value), final, final)
        }
    }

    func testTheCountRisesMonotonicallyAndGroupsAsTheFinalTextDoes() throws {
        let run = try XCTUnwrap(FWCountUp.Run(final: "$12,814.22"))
        var previous = Decimal(-1)
        for step in 0 ... 30 {
            let text = run.text(progress: Double(step) / 30)
            let value = try XCTUnwrap(FWDigitRoll.numericValue(text), text)
            XCTAssertGreaterThanOrEqual(value, previous, text)
            previous = value
            XCTAssertTrue(text.hasPrefix("$"))
        }
        XCTAssertEqual(run.text(at: 1234.5), "$1,234.50")
        // A new value mid-count: the count carries on from the shown value.
        let retarget = run.starting(at: 5000)
        XCTAssertEqual(retarget.text(progress: 0), "$5,000.00")
        XCTAssertEqual(retarget.text(progress: 1), "$12,814.22")
        XCTAssertEqual(run.text(at: 999.999), "$999.99")
    }

    func testTextsWithoutAReproducibleNumberAreShownAtOnce() {
        XCTAssertNil(FWCountUp.Run(final: "—"))
        XCTAssertNil(FWCountUp.Run(final: "N/A"))
        // Lakh grouping cannot be written back with three-digit groups.
        XCTAssertNil(FWCountUp.Run(final: "₹1,23,456.00"))
    }

    func testTheFirstRevealIsClaimedOnce() {
        // A zero total ("$0" before prices load) is never the reveal; the first value above zero after launch is, and
        // only once: later values roll.
        XCTAssertFalse(FWLivingBalance.claimFirstReveal(previous: nil, new: "$0"))
        XCTAssertFalse(FWLivingBalance.claimFirstReveal(previous: "$0.00", new: "—"))
        _ = FWLivingBalance.claimFirstReveal(previous: "$0", new: "$1.00")
        XCTAssertFalse(FWLivingBalance.claimFirstReveal(previous: nil, new: "$2.00"))
        XCTAssertFalse(FWLivingBalance.claimFirstReveal(previous: "$1.00", new: "$2.00"))
    }
}

/// Every text on the sky card keeps 4.5:1 against the brightest pixel the scrim lets through behind it.
final class FWSkyCardContrastTests: XCTestCase {
    func testEveryTextColourKeepsItsContrastOverTheSky() throws {
        for size in [CGSize(width: 362, height: 252), CGSize(width: 280, height: 300), CGSize(width: 680, height: 260)] {
            let card = FWSkyCardView()
            card.frame = CGRect(origin: .zero, size: size)
            card.sunCenter = CGPoint(x: size.width / 2, y: 58)
            card.textTop = 108
            // The rim is a 1 pt edge outside the sampled text area, and `render(in:)` ignores masks.
            card.rim.isHidden = true
            card.layoutIfNeeded()
            let brightest = try XCTUnwrap(Self.brightestLuminance(in: card, below: 108), "\(size)")
            for (name, color) in [
                ("textPrimary", FWSunlit.Palette.textPrimary),
                ("textSecondary", FWSunlit.Palette.textSecondary),
                ("priceUp", FWSunlit.Palette.priceUp),
                ("priceDown", FWSunlit.Palette.priceDown)
            ] {
                let ratio = (FWSunlit.luminance(color) + 0.05) / (brightest + 0.05)
                XCTAssertGreaterThanOrEqual(ratio, 4.5, "\(name) on the sky card \(size): \(ratio)")
            }
        }
    }

    /// The highest relative luminance among the card's pixels from `top` down, away from the rim.
    private static func brightestLuminance(in view: UIView, below top: CGFloat) -> CGFloat? {
        let size = view.bounds.size
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            FWSunlit.Palette.background.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            view.layer.render(in: context.cgContext)
        }
        guard let cgImage = image.cgImage, let data = cgImage.dataProvider?.data,
              let bytes = CFDataGetBytePtr(data) else { return nil }
        let width = cgImage.width, height = cgImage.height, row = cgImage.bytesPerRow
        let channels = cgImage.bitsPerPixel / 8
        let alphaFirst = [.premultipliedFirst, .first, .noneSkipFirst].contains(cgImage.alphaInfo)
        let bgr = cgImage.bitmapInfo.contains(.byteOrder32Little)
        func linear(_ value: UInt8) -> CGFloat {
            let channel = CGFloat(value) / 255
            return channel <= 0.039_28 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        var brightest: CGFloat = 0
        for y in Int(top) ..< max(Int(top), height - 8) {
            for x in 12 ..< max(12, width - 12) {
                let offset = y * row + x * channels
                var rgb = (bytes[offset], bytes[offset + 1], bytes[offset + 2])
                if bgr {
                    rgb = alphaFirst ? (bytes[offset + 2], bytes[offset + 1], bytes[offset]) : (bytes[offset + 2], bytes[offset + 1], bytes[offset])
                } else if alphaFirst {
                    rgb = (bytes[offset + 1], bytes[offset + 2], bytes[offset + 3])
                }
                let luminance = 0.2126 * linear(rgb.0) + 0.7152 * linear(rgb.1) + 0.0722 * linear(rgb.2)
                brightest = max(brightest, luminance)
            }
        }
        return brightest
    }
}
