@testable import fearless
import SoraFoundation
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

    /// A radial gradient with no end point has no radius and paints nothing: the aurora's glows must show.
    func testTheAuroraGlowsActuallyPaint() throws {
        let aurora = FWAuroraView()
        aurora.frame = CGRect(x: 0, y: 0, width: 400, height: 800)
        aurora.layoutIfNeeded()
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let image = UIGraphicsImageRenderer(size: aurora.bounds.size, format: format).image { context in
            UIColor.black.setFill()
            context.fill(aurora.bounds)
            aurora.layer.render(in: context.cgContext)
        }
        let cgImage = try XCTUnwrap(image.cgImage)
        let data = try XCTUnwrap(cgImage.dataProvider?.data)
        let bytes = try XCTUnwrap(CFDataGetBytePtr(data))
        func brightest(atX x: Int, y: Int) -> UInt8 {
            let offset = y * cgImage.bytesPerRow + x * (cgImage.bitsPerPixel / 8)
            // Opaque bitmaps carry one padding byte, first or last: the smaller of the two maxima skips it.
            let first = max(bytes[offset], bytes[offset + 1], bytes[offset + 2])
            let last = max(bytes[offset + 1], bytes[offset + 2], bytes[offset + 3])
            return min(first, last)
        }
        // The pink glow's centre (20 % across, 18 % down) and the ember's (85 %, 55 %) are lit; each stays faint.
        for (x, y) in [(80, 144), (340, 440)] {
            let value = brightest(atX: x, y: y)
            XCTAssertGreaterThan(value, 12, "(\(x), \(y))")
            XCTAssertLessThan(value, 60, "(\(x), \(y))")
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

/// The send success ignite stays centred on the mark and ends at least 16 pt above the title, on the smallest and the
/// largest supported phones and at the largest accessibility text size, while drawing and once settled.
@MainActor
final class AllDoneSolarGeometryLayoutTests: XCTestCase {
    func testTheFigureIsCentredOnTheMarkAndClearOfTheTitle() throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let snapshots = ProcessInfo.processInfo.environment["FW_LAYOUT_SNAPSHOT_DIR"].map { URL(fileURLWithPath: $0) }
        let sizes = [CGSize(width: 375, height: 667), CGSize(width: 402, height: 874), CGSize(width: 440, height: 956)]
        for size in sizes {
            for category in [UIContentSizeCategory.large, .accessibilityExtraExtraExtraLarge] {
                let window = UIWindow(windowScene: scene)
                window.frame = CGRect(origin: .zero, size: size)
                if #available(iOS 17.0, *) {
                    window.traitOverrides.preferredContentSizeCategory = category
                }
                let controller = AllDoneViewController(
                    output: AllDoneOutputStub(),
                    localizationManager: LocalizationManager.shared,
                    celebration: .send,
                    feedback: FeedbackRecorder()
                )
                window.rootViewController = controller
                window.makeKeyAndVisible()
                let layout = controller.rootView
                layout.bind(AllDoneViewModel(
                    title: "All done", description: "You can return to the app",
                    extrinsicHash: "0x5f0d7a91c2e4b8", isWalletConnectResult: false
                ))
                layout.setNeedsLayout()
                layout.layoutIfNeeded()
                let label = "\(Int(size.width))x\(Int(size.height)) \(category.rawValue)"
                for (state, progress, alpha) in [("drawing", 0.55, CGFloat(1)), ("settled", 1.0, CGFloat(0.25))] {
                    layout.solarGeometryView.isHidden = false
                    layout.solarGeometryView.alpha = alpha
                    layout.solarGeometryView.setProgress(progress)
                    let figure = layout.solarGeometryView.convert(layout.solarGeometryView.bounds, to: layout)
                    let mark = layout.imageViewContainer.convert(layout.imageViewContainer.bounds, to: layout)
                    let title = layout.titleLabel.convert(layout.titleLabel.bounds, to: layout)
                    XCTAssertEqual(figure.midX, mark.midX, accuracy: 0.5, "\(label) \(state)")
                    XCTAssertEqual(figure.midY, mark.midY, accuracy: 0.5, "\(label) \(state)")
                    XCTAssertFalse(figure.intersects(title), "\(label) \(state): figure \(figure) meets title \(title)")
                    XCTAssertLessThanOrEqual(figure.maxY + 16, title.minY + 0.5, "\(label) \(state)")
                    // The drawn ring keeps at least 1.6 times the mark's dark disc.
                    XCTAssertGreaterThanOrEqual(layout.solarGeometryView.radius * 2, 1.6 * mark.width, "\(label) \(state)")
                    if let snapshots {
                        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
                            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
                        }
                        let name = "all-done-\(Int(size.width))x\(Int(size.height))-\(category == .large ? "default" : "ax5")-\(state).png"
                        try image.pngData()?.write(to: snapshots.appendingPathComponent(name))
                    }
                }
                window.isHidden = true
            }
        }
        XCTAssertEqual(AllDoneViewLayout.solarGeometryTitleSpacing, 64)
        XCTAssertGreaterThanOrEqual(AllDoneViewLayout.solarGeometrySide, 1.6 * AllDoneViewLayout.markSide)
    }
}

private final class AllDoneOutputStub: AllDoneViewOutput {
    func didLoad(view _: AllDoneViewInput) {}
    func dismiss() {}
    func didCopyTapped() {}
    func presentationControllerWillDismiss() {}
    func explorerButtonDidTapped() {}
    func shareButtonDidTapped() {}
}
