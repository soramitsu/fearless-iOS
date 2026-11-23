import SwiftUI

/// A small capsule that states a status with an icon and words, never with
/// colour alone.
public struct StatusPill: View {
    public enum Kind: Sendable {
        case success, pending, failed, warning, neutral, testnet

        var color: Color {
            switch self {
            case .success: return BrandColor.final
            case .pending: return BrandColor.inFlight
            case .failed: return BrandColor.failure
            case .warning, .testnet: return BrandColor.warning
            case .neutral: return .secondary
            }
        }

        var symbol: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .pending: return "clock.fill"
            case .failed: return "xmark.octagon.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .neutral: return "circle.fill"
            case .testnet: return "flask.fill"
            }
        }
    }

    private let text: String
    private let kind: Kind
    private let showsIcon: Bool

    @Environment(\.colorSchemeContrast) private var contrast

    public init(_ text: String, kind: Kind, showsIcon: Bool = true) {
        self.text = text
        self.kind = kind
        self.showsIcon = showsIcon
    }

    public var body: some View {
        HStack(spacing: 4) {
            if showsIcon {
                Image(systemName: kind.symbol).font(.system(size: 9, weight: .semibold))
            }
            Text(text).font(.caption.weight(.medium))
        }
        .foregroundStyle(kind.color)
        .padding(.horizontal, 7)
        .padding(.vertical, 2.5)
        .background(kind.color.opacity(contrast == .increased ? 0.0 : 0.13), in: Capsule())
        .overlay(Capsule().strokeBorder(kind.color.opacity(contrast == .increased ? 0.9 : 0.25), lineWidth: contrast == .increased ? 1 : 0.5))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }
}
