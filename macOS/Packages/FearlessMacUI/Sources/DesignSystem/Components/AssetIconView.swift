import SwiftUI
import WalletCore

/// An asset's round icon with an optional small network badge. Uses the
/// coloured token icon the catalog names (`tokenIconName`), then a bundled
/// token icon matching the ticker symbol, then the chain glyph named by the
/// catalog, then a monogram of the symbol.
public struct AssetIconView: View {
    public struct NetworkBadge {
        public let name: String
        public let iconName: String?
        public let accentHex: String?

        public init(name: String, iconName: String?, accentHex: String?) {
            self.name = name
            self.iconName = iconName
            self.accentHex = accentHex
        }
    }

    private let symbol: String
    private let tokenIconName: String?
    private let iconName: String?
    private let accentHex: String?
    private let size: CGFloat
    private let badge: NetworkBadge?

    public init(
        symbol: String,
        tokenIconName: String? = nil,
        iconName: String? = nil,
        accentHex: String? = nil,
        size: CGFloat = 28,
        badge: NetworkBadge? = nil
    ) {
        self.symbol = symbol
        self.tokenIconName = tokenIconName
        self.iconName = iconName
        self.accentHex = accentHex
        self.size = size
        self.badge = badge
    }

    /// The icon of a catalog asset, optionally with its network as a badge.
    public init(asset: Asset?, chain: Chain?, fallbackSymbol: String = "?", size: CGFloat = 28, showsNetworkBadge: Bool = false) {
        self.init(
            symbol: asset?.symbol ?? fallbackSymbol,
            tokenIconName: asset?.tokenIconName,
            iconName: asset?.iconName,
            accentHex: chain?.accentHex,
            size: size,
            badge: showsNetworkBadge ? chain.map { NetworkBadge(name: $0.name, iconName: $0.iconName, accentHex: $0.accentHex) } : nil
        )
    }

    public var body: some View {
        icon
            .frame(width: size, height: size)
            .overlay(alignment: .bottomTrailing) {
                if let badge {
                    ChainIconView(name: badge.name, iconName: badge.iconName, accentHex: badge.accentHex, size: max(10, size * 0.46))
                        .overlay(Circle().strokeBorder(Color(nsColor: .windowBackgroundColor), lineWidth: 1.5))
                        .offset(x: size * 0.14, y: size * 0.14)
                }
            }
            .accessibilityHidden(true)
    }

    @ViewBuilder private var icon: some View {
        if let token = IconLibrary.tokenIcon(named: tokenIconName) ?? IconLibrary.tokenIcon(named: symbol) {
            // Token files keep a two-unit margin in a 24-unit box.
            Image(nsImage: token)
                .resizable()
                .interpolation(.high)
                .scaleEffect(1.2)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5))
        } else if IconLibrary.chainGlyph(named: iconName) != nil {
            ChainIconView(name: symbol, iconName: iconName, accentHex: accentHex, size: size)
        } else {
            ZStack {
                Circle().fill(Color(hexString: accentHex) ?? IconLibrary.monogramColor(for: symbol))
                Monogram(text: symbol, size: size, color: Color(hexString: accentHex) == nil ? .white : IconContrast.glyphColor(accentHex: accentHex))
            }
            .overlay(Circle().strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5))
        }
    }
}
