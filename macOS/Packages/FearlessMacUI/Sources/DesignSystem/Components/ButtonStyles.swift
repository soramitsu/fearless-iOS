import SwiftUI

public extension View {
    /// The primary action: the system's prominent button in brand pink.
    /// Shape, focus ring, default-button behaviour and sizing stay native.
    func brandProminentButton() -> some View {
        buttonStyle(.borderedProminent).tint(BrandColor.accentFill)
    }

    /// Brand tint for native controls (switches, progress, selection).
    func brandTint() -> some View {
        tint(BrandColor.accent)
    }
}

/// A large choice on a brand surface (onboarding): a lit glass card with a
/// title, a line of explanation and a symbol. Presses settle, they do not bounce.
public struct ChoiceCardButtonStyle: ButtonStyle {
    private let prominent: Bool

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    public init(prominent: Bool) {
        self.prominent = prominent
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(18)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(fill(pressed: configuration.isPressed))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(LitRim.gradient, lineWidth: 1)
                    .opacity(prominent ? 0.9 : 0.7)
            }
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .opacity(isEnabled ? 1 : 0.5)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .animation(reduceMotion ? nil : BrandMotion.settle(BrandMotion.d180), value: configuration.isPressed)
    }

    private func fill(pressed: Bool) -> AnyShapeStyle {
        if prominent {
            return AnyShapeStyle(pressed ? BrandColor.accentFillPressed : BrandColor.accentFill)
        }
        let base = reduceTransparency ? BrandPalette.night : BrandPalette.text.opacity(pressed ? 0.14 : 0.08)
        return AnyShapeStyle(base)
    }
}

/// The kit's lit rim: gold on the upper left fading through pink to nothing.
public enum LitRim {
    public static let gradient = LinearGradient(
        stops: [
            .init(color: BrandPalette.gold.opacity(0.55), location: 0),
            .init(color: BrandPalette.pinkText.opacity(0.30), location: 0.5),
            .init(color: BrandPalette.pinkText.opacity(0), location: 1)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
