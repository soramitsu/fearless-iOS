import SwiftUI

/// A network's round icon: its white glyph on its brand colour, or a
/// monogram when no glyph is bundled.
public struct ChainIconView: View {
    private let name: String
    private let iconName: String?
    private let accent: Color
    /// White, or ink when the catalog's colour is too pale for white.
    private let glyphColor: Color
    private let isPale: Bool
    private let size: CGFloat

    public init(name: String, iconName: String?, accentHex: String?, size: CGFloat = 24) {
        self.name = name
        self.iconName = iconName
        let parsed = Color(hexString: accentHex)
        self.accent = parsed ?? IconLibrary.fallbackAccent(iconName: iconName, name: name)
        let pale = parsed != nil && IconContrast.needsDarkGlyph(accentHex: accentHex)
        self.isPale = pale
        self.glyphColor = pale ? BrandPalette.ink : .white
        self.size = size
    }

    public var body: some View {
        ZStack {
            Circle().fill(accent)
            if let glyph = IconLibrary.chainGlyph(named: iconName) {
                if let scale = IconLibrary.discScale(named: iconName) {
                    // The file is a disc with the mark cut out: keep only the mark.
                    Circle()
                        .fill(glyphColor)
                        .mask {
                            ZStack {
                                Circle().fill(.black)
                                Image(nsImage: glyph)
                                    .resizable()
                                    .renderingMode(.template)
                                    .foregroundStyle(.black)
                                    .scaleEffect(scale * 1.03)
                                    .blendMode(.destinationOut)
                            }
                            .compositingGroup()
                        }
                } else {
                    Image(nsImage: glyph)
                        .resizable()
                        .renderingMode(.template)
                        .foregroundStyle(glyphColor)
                        .aspectRatio(contentMode: .fit)
                        .padding(size * 0.22)
                }
            } else {
                Monogram(text: name, size: size, color: glyphColor)
            }
        }
        .frame(width: size, height: size)
        // A pale disc on a light window (or a dark one on a dark window) keeps its edge.
        .overlay(Circle().strokeBorder(Color.primary.opacity(isPale ? 0.35 : 0.22), lineWidth: 0.5))
        .accessibilityHidden(true)
    }
}

/// One or two letters on a disc, for icons that are not bundled.
struct Monogram: View {
    let text: String
    let size: CGFloat
    var color: Color = .white

    var body: some View {
        Text(initials)
            .font(.system(size: size * (initials.count > 1 ? 0.36 : 0.46), weight: .bold, design: .rounded))
            .foregroundStyle(color)
            .minimumScaleFactor(0.5)
            .lineLimit(1)
    }

    private var initials: String {
        let letters = text.filter { $0.isLetter || $0.isNumber }
        return String(letters.prefix(text.count <= 4 ? 1 : 2)).uppercased()
    }
}
