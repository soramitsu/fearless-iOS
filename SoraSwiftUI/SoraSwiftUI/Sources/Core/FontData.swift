import Foundation
import UIKit


extension FontWeight {
    var uiKitWeight: UIFont.Weight  {
        switch self {
        case .one: return .bold
        case .zero: return .regular
        }
    }
}

public struct FontData {
    let fontFamily: FontFamily
    let fontSize: CGFloat
    let fontWeight: FontWeight
    let letterSpacing: CGFloat
    let lineHeight: CGFloat
    let paragraphSpacing: CGFloat

    public var font: UIFont {
        return UIFont(name: "\(fontFamily)-\(fontWeight)", size: fontSize) ?? .systemFont(ofSize: fontSize, weight: fontWeight.uiKitWeight)
    }

    var paragraph: NSMutableParagraphStyle {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = lineHeight - fontSize
        paragraphStyle.paragraphSpacing = self.paragraphSpacing
        return paragraphStyle
    }

    public var attributes: [NSAttributedString.Key: Any] {
        let paragraphStyle = NSMutableParagraphStyle()

        paragraphStyle.lineSpacing = lineHeight - fontSize
        paragraphStyle.paragraphSpacing = self.paragraphSpacing

        return [.paragraphStyle: paragraphStyle,
                .font: font,
                .kern: letterSpacing
        ]
    }

    public func attriburedString(with text: String) -> NSMutableAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()

        paragraphStyle.lineSpacing = lineHeight - fontSize
        paragraphStyle.paragraphSpacing = self.paragraphSpacing

        return NSMutableAttributedString(string: text, attributes: [ .font: font,
                                                              .kern: letterSpacing,
                                                              .paragraphStyle: paragraphStyle ])
    }
}

@objc
public final class TypographyConstants: NSObject {
    @objc public class func registerFonts(from bundle: Bundle) {
        let fontFamilies = FontFamily.allCases.map { $0.rawValue }
        let fontWeights = FontWeight.allCases.map { $0.rawValue }

        var fonts: [String] = []
        fontFamilies.forEach { fontFamily in
            fontWeights.forEach { fontWeight in
                fonts.append("\(fontFamily)-\(fontWeight)")
            }
        }

        for fontName in fonts {
            if let url = bundle.url(forResource: fontName,
                                     withExtension: "otf"),
                let data = try? Data(contentsOf: url),
                let provider = CGDataProvider(data: data as CFData),
                let font = CGFont(provider) {
                CTFontManagerRegisterGraphicsFont(font, nil)
            }
        }
    }
}
