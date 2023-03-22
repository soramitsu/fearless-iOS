import Foundation

// #codegen
enum FontFamily: String, CaseIterable {
	case headline = "Sora"
	case text = "Inter"
}

enum FontWeight: String, CaseIterable {
	case zero = "Regular"
	case one = "Bold"
}

public enum FontType {
	public static let headline4: FontData = FontData(fontFamily: .headline,
												fontSize: 13,
												fontWeight: .zero,
												letterSpacing: 0.0,
												lineHeight: 16,
												paragraphSpacing: 0)

	public static let headline3: FontData = FontData(fontFamily: .headline,
												fontSize: 15,
												fontWeight: .one,
												letterSpacing: 0.0,
												lineHeight: 24,
												paragraphSpacing: 0)

	public static let headline2: FontData = FontData(fontFamily: .headline,
												fontSize: 18,
												fontWeight: .one,
												letterSpacing: 0.0,
												lineHeight: 24,
												paragraphSpacing: 0)

	public static let headline1: FontData = FontData(fontFamily: .headline,
												fontSize: 24,
												fontWeight: .one,
												letterSpacing: 0.0,
												lineHeight: 32,
												paragraphSpacing: 0)

	public static let buttonM: FontData = FontData(fontFamily: .headline,
												fontSize: 16,
												fontWeight: .one,
												letterSpacing: 0.0,
												lineHeight: 16,
												paragraphSpacing: 0)

	public static let paragraphM: FontData = FontData(fontFamily: .text,
												fontSize: 16,
												fontWeight: .zero,
												letterSpacing: 0.0,
												lineHeight: 24,
												paragraphSpacing: 0)

	public static let paragraphBoldL: FontData = FontData(fontFamily: .text,
												fontSize: 18,
												fontWeight: .one,
												letterSpacing: 0.0,
												lineHeight: 28,
												paragraphSpacing: 0)

	public static let paragraphBoldM: FontData = FontData(fontFamily: .text,
												fontSize: 16,
												fontWeight: .one,
												letterSpacing: 0.0,
												lineHeight: 24,
												paragraphSpacing: 0)

	public static let paragraphBoldS: FontData = FontData(fontFamily: .text,
												fontSize: 14,
												fontWeight: .one,
												letterSpacing: 0.0,
												lineHeight: 20,
												paragraphSpacing: 0)

	public static let paragraphBoldXS: FontData = FontData(fontFamily: .text,
												fontSize: 12,
												fontWeight: .one,
												letterSpacing: 0.0,
												lineHeight: 16,
												paragraphSpacing: 0)

	public static let paragraphXS: FontData = FontData(fontFamily: .text,
												fontSize: 12,
												fontWeight: .zero,
												letterSpacing: 0.0,
												lineHeight: 16,
												paragraphSpacing: 0)

	public static let paragraphS: FontData = FontData(fontFamily: .text,
												fontSize: 14,
												fontWeight: .zero,
												letterSpacing: 0.0,
												lineHeight: 20,
												paragraphSpacing: 0)

	public static let paragraphL: FontData = FontData(fontFamily: .text,
												fontSize: 18,
												fontWeight: .zero,
												letterSpacing: 0.0,
												lineHeight: 28,
												paragraphSpacing: 0)

	public static let textM: FontData = FontData(fontFamily: .text,
												fontSize: 16,
												fontWeight: .zero,
												letterSpacing: 0.0,
												lineHeight: 16,
												paragraphSpacing: 0)

	public static let textXS: FontData = FontData(fontFamily: .text,
												fontSize: 12,
												fontWeight: .zero,
												letterSpacing: 0.0,
												lineHeight: 12,
												paragraphSpacing: 0)

	public static let textS: FontData = FontData(fontFamily: .text,
												fontSize: 14,
												fontWeight: .zero,
												letterSpacing: 0.0,
												lineHeight: 16,
												paragraphSpacing: 0)

	public static let textL: FontData = FontData(fontFamily: .text,
												fontSize: 18,
												fontWeight: .zero,
												letterSpacing: 0.0,
												lineHeight: 20,
												paragraphSpacing: 0)

	public static let textBoldL: FontData = FontData(fontFamily: .text,
												fontSize: 18,
												fontWeight: .one,
												letterSpacing: 0.0,
												lineHeight: 20,
												paragraphSpacing: 0)

	public static let textBoldS: FontData = FontData(fontFamily: .text,
												fontSize: 14,
												fontWeight: .one,
												letterSpacing: 0.0,
												lineHeight: 16,
												paragraphSpacing: 0)

	public static let textBoldXS: FontData = FontData(fontFamily: .text,
												fontSize: 12,
												fontWeight: .one,
												letterSpacing: 0.0,
												lineHeight: 12,
												paragraphSpacing: 0)

	public static let textBoldM: FontData = FontData(fontFamily: .text,
												fontSize: 16,
												fontWeight: .one,
												letterSpacing: 0.0,
												lineHeight: 16,
												paragraphSpacing: 0)

	public static let displayM: FontData = FontData(fontFamily: .headline,
												fontSize: 24,
												fontWeight: .one,
												letterSpacing: 0.0,
												lineHeight: 32,
												paragraphSpacing: 0)

	public static let displayL: FontData = FontData(fontFamily: .headline,
												fontSize: 34,
												fontWeight: .one,
												letterSpacing: 0.0,
												lineHeight: 40,
												paragraphSpacing: 0)

	public static let displayS: FontData = FontData(fontFamily: .headline,
												fontSize: 18,
												fontWeight: .one,
												letterSpacing: 0.0,
												lineHeight: 24,
												paragraphSpacing: 0)
}