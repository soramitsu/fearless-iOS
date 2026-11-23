import SwiftUI

/// A content card on the window background: rounded, with a hairline rim.
/// Honours Reduce Transparency (always opaque) and Increase Contrast.
public struct CardModifier: ViewModifier {
    private let padding: CGFloat

    @Environment(\.colorSchemeContrast) private var contrast

    public init(padding: CGFloat = 16) {
        self.padding = padding
    }

    public func body(content: Content) -> some View {
        content
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(BrandColor.card)
                    .shadow(color: .black.opacity(0.06), radius: 3, y: 1)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.primary.opacity(contrast == .increased ? 0.5 : 0.09), lineWidth: contrast == .increased ? 1 : 0.5)
            }
    }
}

public extension View {
    func card(padding: CGFloat = 16) -> some View {
        modifier(CardModifier(padding: padding))
    }
}

/// A card heading with an optional trailing accessory.
public struct CardHeader<Accessory: View>: View {
    private let title: String
    private let accessory: Accessory

    public init(_ title: String, @ViewBuilder accessory: () -> Accessory) {
        self.title = title
        self.accessory = accessory()
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            accessory
        }
    }
}

public extension CardHeader where Accessory == EmptyView {
    init(_ title: String) {
        self.init(title) { EmptyView() }
    }
}
