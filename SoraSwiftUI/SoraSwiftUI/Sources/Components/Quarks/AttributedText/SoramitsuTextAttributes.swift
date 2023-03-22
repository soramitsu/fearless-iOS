import UIKit

public struct SoramitsuTextAttributes {

	public var fontData: FontData
	public var textColor: SoramitsuColor
	public var alignment: NSTextAlignment?
	public var underline: NSUnderlineStyle?

	var linkTapHandler: (() -> Void)?

	public static var `default`: SoramitsuTextAttributes {
        SoramitsuTextAttributes(fontData: FontType.textM,
                        textColor: .bgSurfaceInverted)
	}

	public static func link(fontData: FontData,
							textColor: SoramitsuColor = .accentPrimary,
							alignment: NSTextAlignment = .left,
							tapHandler: (() -> Void)? = nil) -> SoramitsuTextAttributes {
		var attributes = SoramitsuTextAttributes(fontData: fontData,
										 textColor: textColor,
										 alignment: alignment)
		attributes.linkTapHandler = tapHandler
		return attributes
	}

	public init(fontData: FontData,
				textColor: SoramitsuColor,
				alignment: NSTextAlignment = .left,
				underline: NSUnderlineStyle? = nil) {
        self.fontData = fontData
		self.textColor = textColor
		self.alignment = alignment
		self.underline = underline
	}
}
