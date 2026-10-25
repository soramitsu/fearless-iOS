import CoreText
@testable import fearless
import UIKit
import XCTest

@MainActor
final class FWFontMigrationTests: XCTestCase {
    func testAllSixFontResourcesAreRegisteredWithTheirActualPostScriptNames() throws {
        let fonts = [
            "sora-Regular.otf": "Sora-Regular", "sora-SemiBold.otf": "Sora-SemiBold",
            "sora-Bold.otf": "Sora-Bold", "sora-ExtraBold.otf": "Sora-ExtraBold",
            "JetBrainsMono-Regular.ttf": "JetBrainsMono-Regular", "JetBrainsMono-Medium.ttf": "JetBrainsMono-Medium"
        ]
        let registered = try XCTUnwrap(Bundle.main.object(forInfoDictionaryKey: "UIAppFonts") as? [String])
        for (file, name) in fonts {
            XCTAssertTrue(registered.contains(file))
            let resource = file as NSString
            XCTAssertNotNil(Bundle.main.url(forResource: resource.deletingPathExtension, withExtension: resource.pathExtension))
            XCTAssertEqual(try XCTUnwrap(UIFont(name: name, size: 16)).fontName, name)
        }
    }

    func testLegacyStylesKeepTheirSoraSizesAndTabularDigits() {
        let traits = UITraitCollection(preferredContentSizeCategory: .large)
        traits.performAsCurrent {
            let roles: [(UIFont, CGFloat)] = [
                (.h1Title, 30), (.h2Title, 22), (.h3Title, 18), (.h4Title, 16), (.h5Title, 14), (.h6Title, 12),
                (.capsTitle, 12), (.p0Paragraph, 16), (.p0Digits, 16), (.p1Paragraph, 14), (.p2Paragraph, 12), (.p3Paragraph, 12)
            ]
            for (font, size) in roles {
                XCTAssertTrue(font.fontName.hasPrefix("Sora-"))
                XCTAssertEqual(font.pointSize, size, accuracy: 0.01)
            }
            XCTAssertEqual(
                "11111".size(withAttributes: [.font: UIFont.p0Digits]).width,
                "88888".size(withAttributes: [.font: UIFont.p0Digits]).width,
                accuracy: 0.01
            )
        }
    }

    func testLegacySoraBoldTextStepsAndDynamicTypeAreExplicit() {
        let normal = UITraitCollection(preferredContentSizeCategory: .large)
        let large = UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge)
        let weights: [(UIFont.Weight, String, String)] = [
            (.regular, "Sora-Regular", "Sora-SemiBold"), (.semibold, "Sora-SemiBold", "Sora-Bold"),
            (.bold, "Sora-Bold", "Sora-ExtraBold")
        ]
        for (weight, name, boldName) in weights {
            XCTAssertEqual(UIFont.legacySora(size: 16, weight: weight, compatibleWith: normal, boldText: false).fontName, name)
            XCTAssertEqual(UIFont.legacySora(size: 16, weight: weight, compatibleWith: normal, boldText: true).fontName, boldName)
            let scaled = UIFont.legacySora(size: 16, weight: weight, textStyle: .body, compatibleWith: large, boldText: true)
            XCTAssertEqual(scaled.fontName, boldName)
            XCTAssertGreaterThan(scaled.pointSize, 16)
        }
    }

    func testNewRolesUseBundledTitleAndMonoFacesWithoutMovingAmountsAwayFromSystem() {
        let traits = UITraitCollection(preferredContentSizeCategory: .large)
        XCTAssertEqual(UIFont.fw(.titleL, locale: Locale(identifier: "en"), compatibleWith: traits, boldText: false).fontName, "Sora-SemiBold")
        XCTAssertEqual(UIFont.fw(.titleL, locale: Locale(identifier: "tr"), compatibleWith: traits, boldText: true).fontName, "Sora-Bold")
        for language in ["ru", "vi", "ja", "zh-Hans"] {
            XCTAssertFalse(UIFont.fw(.titleL, locale: Locale(identifier: language), compatibleWith: traits).fontName.contains("Sora"))
        }
        XCTAssertEqual(UIFont.fw(.monoM, compatibleWith: traits, boldText: false).fontName, "JetBrainsMono-Regular")
        XCTAssertEqual(UIFont.fw(.monoM, compatibleWith: traits, boldText: true).fontName, "JetBrainsMono-Medium")
        for style in [FWFontStyle.displayXL, .displayL, .numberL, .numberM, .numberS, .bodyM, .phraseWord] {
            let font = UIFont.fw(style, compatibleWith: traits)
            XCTAssertFalse(font.fontName.contains("Sora"))
            XCTAssertFalse(font.fontName.contains("JetBrains"))
        }
        for language in ["ja", "zh-Hans"] {
            XCTAssertFalse(UIFont.fw(.hud, locale: Locale(identifier: language), compatibleWith: traits).fontName.contains("JetBrains"))
        }
    }

    func testBundledMonoCoversExactAddressAlphabetAndSystemAmountGlyphs() throws {
        let mono = try XCTUnwrap(UIFont(name: "JetBrainsMono-Regular", size: 16))
        let alphabet = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz:/._-".utf16)
        var glyphs = [CGGlyph](repeating: 0, count: alphabet.count)
        XCTAssertTrue(CTFontGetGlyphsForCharacters(mono as CTFont, alphabet, &glyphs, alphabet.count))
        XCTAssertFalse(glyphs.contains(0))
        let symbols = Array("≈−₽₹₺₩₫€£¥".utf16)
        var amountGlyphs = [CGGlyph](repeating: 0, count: symbols.count)
        XCTAssertTrue(CTFontGetGlyphsForCharacters(UIFont.fw(.numberM) as CTFont, symbols, &amountGlyphs, symbols.count))
    }
}
