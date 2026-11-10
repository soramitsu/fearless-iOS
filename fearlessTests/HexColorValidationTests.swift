import UIKit
import XCTest
@testable import fearless

final class HexColorValidationTests: XCTestCase {
    func testOnlyCompleteSixDigitHexValuesAreAccepted() throws {
        for value in ["GGGGGG", "FFFFFG", "00xx00", "12345", "1234567"] {
            XCTAssertNil(HexColorConverter.hexStringToUIColor(hex: value))
        }
        XCTAssertNil(HexColorConverter.hexStringToUIColor(hex: nil))
        XCTAssertEqual(HexColorConverter.hexStringToUIColor(hex: " #ff0000\n"), UIColor.red)
        let black = try XCTUnwrap(HexColorConverter.hexStringToUIColor(hex: "000000"))
        var red: CGFloat = 1
        var green: CGFloat = 1
        var blue: CGFloat = 1
        var alpha: CGFloat = 0
        XCTAssertTrue(black.getRed(&red, green: &green, blue: &blue, alpha: &alpha))
        XCTAssertEqual([red, green, blue, alpha], [0, 0, 0, 1])
    }
}

/// Remote icons (dApp-chosen and NFT images included) reach SVGKit only as small,
/// self-contained documents; everything else keeps the placeholder.
final class RemoteSVGFilterTests: XCTestCase {
    private func svg(_ body: String, prolog: String = "") -> Data {
        let open = #"<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink""#
            + #" width="24" height="24" viewBox="0 0 24 24">"#
        return Data((prolog + open + body + "</svg>").utf8)
    }

    private func pngBase64() throws -> String {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
        }
        return try XCTUnwrap(image.pngData()).base64EncodedString()
    }

    /// The filter decides only whether SVGKit may parse the bytes; whether SVGKit then draws them is SVGKit's
    /// business (in a test host it rasterises no paths at all), so this checks the decision.
    func testSelfContainedIconsAreAllowed() throws {
        let png = try pngBase64()
        let wrapped = String(png.prefix(8)) + "\n  " + String(png.dropFirst(8))
        let allowed = [
            svg(##"<path d="M0 0h24v24H0z" fill="#3c3c3c"/>"##),
            svg(
                ##"<defs><linearGradient id="g"><stop offset="0" stop-color="#000"/><stop offset="1" stop-color="#fff"/>"##
                    + ##"</linearGradient></defs><path d="M0 0h24v24H0z" fill="url(#g)"/>"##
            ),
            svg(
                ##"<defs><linearGradient id="g"/></defs><use xlink:href="#g"/>"##
                    + #"<style><![CDATA[.a{fill:url( '#g' )}]]></style><!-- exported icon -->"#,
                prolog: #"<?xml version="1.0" encoding="UTF-8"?>"#
            ),
            svg(#"<g style="fill:url(#a)" stroke="URL('#b')" opacity="0.5" font-family="Montserrat"/>"#),
            svg(#"<image width="2" height="2" href="data:image/png;base64,\#(png)"/>"#),
            svg(#"<image width="2" height="2" xlink:href="data:image/png;base64,\#(wrapped)"/>"#)
        ]
        for data in allowed {
            XCTAssertTrue(RemoteSVGFilter.isAllowed(data), String(decoding: data, as: UTF8.self))
        }
        let raster = try XCTUnwrap(Data(base64Encoded: png))
        let image = try XCTUnwrap(RemoteSVGFilter.image(from: raster), "Raster images never reach the SVG filter")
        // The fixture renders at the screen's scale, so only a real, non-empty image is required.
        XCTAssertGreaterThan(image.size.width, 0)
        XCTAssertGreaterThan(image.size.height, 0)
    }

    func testOversizedInvalidAndMultiByteEncodedDocumentsAreRefused() {
        let oversized = svg("<!--" + String(repeating: "a", count: RemoteSVGFilter.maximumByteCount) + "-->")
        let utf16 = String(decoding: svg("<g/>"), as: UTF8.self).data(using: .utf16LittleEndian) ?? Data()
        let refused = [
            oversized,
            svg("") + Data([0xFF]),
            svg("<g/>") + Data([0xC0, 0xAF]),
            utf16,
            svg("", prolog: #"<?xml version="1.0" encoding="UTF-7"?>"#)
        ]
        for data in refused {
            XCTAssertFalse(RemoteSVGFilter.isAllowed(data))
            XCTAssertNil(RemoteSVGFilter.image(from: data), "A refused document keeps the placeholder")
        }
    }

    func testDeclarationsInstructionsAndActiveContentAreRefused() {
        let refused = [
            svg("", prolog: #"<!DOCTYPE svg [<!ENTITY x "y">]>"#),
            svg("", prolog: "<!doctype svg>"),
            svg(#"<!ENTITY x SYSTEM "file:///etc/hosts">"#),
            svg("", prolog: #"<?xml-stylesheet href="https://tracker.example/a.css"?>"#),
            svg("<script>alert(1)</script>"),
            svg(#"<h:script xmlns:h="http://www.w3.org/1999/xhtml"/>"#),
            svg("<foreignObject/>"),
            svg("<iframe/>"),
            svg("<embed/>"),
            svg("<object/>"),
            svg(#"<g onload="run()"/>"#),
            svg(#"<g ev:onclick = "run()"/>"#)
        ]
        for data in refused {
            XCTAssertFalse(RemoteSVGFilter.isAllowed(data), String(decoding: data, as: UTF8.self))
            XCTAssertNil(RemoteSVGFilter.image(from: data))
        }
    }

    func testExternalAndNestedReferencesAreRefused() throws {
        let png = try pngBase64()
        let nested = svg(#"<image href="https://tracker.example/ip.png"/>"#).base64EncodedString()
        let refused = [
            svg(#"<image href="https://tracker.example/ip.png"/>"#),
            svg(#"<image xlink:href="http://tracker.example/ip.png"/>"#),
            svg(#"<image x:href='//tracker.example/ip.png'/>"#),
            svg(#"<use href="other.svg#a"/>"#),
            svg(#"<a href="javascript:alert(1)"/>"#),
            svg(#"<image href=https://tracker.example/>"#),
            svg(#"<g src="https://tracker.example"/>"#),
            svg(#"<image href="&#104;ttps://tracker.example"/>"#),
            svg(#"<image href=""/>"#),
            svg(#"<image href="data:image/svg+xml;base64,\#(nested)"/>"#),
            svg(#"<image href="data:image/png;base64,\#(nested)"/>"#),
            svg(#"<image href="data:image/svg+xml;utf8,&lt;svg/&gt;"/>"#),
            svg(#"<image href="data:image/png,\#(png)"/>"#)
        ]
        for data in refused {
            XCTAssertFalse(RemoteSVGFilter.isAllowed(data), String(decoding: data, as: UTF8.self))
        }
    }

    func testStyleURLsOutsideTheDocumentAndImportsAreRefused() {
        for body in [
            "<style>.a{background:url(https://tracker.example/x)}</style>",
            #"<g style="fill:url('https://tracker.example')"/>"#,
            #"<g style="fill:url(&quot;#a&quot;)"/>"#,
            "<style>@font-face{src:url(data:font/woff2;base64,AAAA)}</style>",
            "<style>@import 'https://tracker.example/x.css';</style>"
        ] {
            XCTAssertFalse(RemoteSVGFilter.isAllowed(svg(body)), body)
        }
    }
}
