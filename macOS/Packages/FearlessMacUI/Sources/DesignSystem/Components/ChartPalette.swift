import SwiftUI

/// Categorical colours for charts, in a fixed order. Colour follows the
/// entity (an asset or a network keeps its slot), never its rank, and the
/// slots are never cycled: anything past the last slot is drawn as "Other".
///
/// Both columns were checked with the data-viz palette validator on the
/// card surface of their mode: lightness band, chroma floor, colour-vision
/// separation of neighbours (worst ΔE 9.2 light, 9.4 dark) and the
/// normal-vision floor (worst ΔE 24.0 light, 20.9 dark). Two light slots sit
/// under 3:1 against white, so a chart using them always shows its figures
/// as text beside it.
public enum ChartPalette {
    private static let light: [UInt32] = [0xD6006A, 0xEDA100, 0x2A78D6, 0x1BAF7A, 0xEB6834, 0x6250D6, 0x008300]
    private static let dark: [UInt32] = [0xE6006F, 0xC98500, 0x3987E5, 0x199E70, 0xD95926, 0x9085E9, 0x0CA30C]

    public static let slotCount = 7

    /// Colour of a slot; nil past the last one (draw it as "Other").
    public static func color(slot: Int) -> Color? {
        guard light.indices.contains(slot) else { return nil }
        return Color.adaptive(light: light[slot], dark: dark[slot])
    }

    /// Neutral fill for the folded tail.
    public static let other = Color.adaptive(light: 0x9A9AA2, dark: 0x6E6E78)
}

/// One whole split into parts, read beside a list that names each part and
/// gives its figures: a thin bar with rounded ends, no text on it, and a
/// surface-coloured gap between parts.
public struct SegmentedShareBar: View {
    public struct Part: Identifiable {
        public let id: String
        public let fraction: Double
        public let color: Color
        /// Tooltip and VoiceOver text: name, amount and share.
        public let summary: String

        public init(id: String, fraction: Double, color: Color, summary: String) {
            self.id = id
            self.fraction = fraction
            self.color = color
            self.summary = summary
        }
    }

    private let parts: [Part]
    private let height: CGFloat

    public init(parts: [Part], height: CGFloat = 10) {
        self.parts = parts.filter { $0.fraction > 0 }
        self.height = height
    }

    public var body: some View {
        GeometryReader { proxy in
            let gap: CGFloat = 2
            let total = parts.reduce(0) { $0 + $1.fraction }
            let available = max(0, proxy.size.width - gap * CGFloat(max(0, parts.count - 1)))
            HStack(spacing: gap) {
                ForEach(parts) { part in
                    Rectangle()
                        .fill(part.color)
                        .frame(width: total > 0 ? max(2, available * part.fraction / total) : 0)
                        .help(part.summary)
                        .accessibilityElement()
                        .accessibilityLabel(part.summary)
                }
            }
            .frame(width: proxy.size.width, alignment: .leading)
            .clipShape(Capsule())
        }
        .frame(height: height)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Allocation")
    }
}
