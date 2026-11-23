import SwiftUI
import WalletCore

/// Four segments and a word for the app password's strength. The word
/// carries the meaning; the colour only supports it.
public struct PasswordStrengthMeter: View {
    private let strength: PasswordStrength
    private let isEmpty: Bool

    public init(strength: PasswordStrength, isEmpty: Bool) {
        self.strength = strength
        self.isEmpty = isEmpty
    }

    public var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 3) {
                ForEach(0..<4, id: \.self) { index in
                    Capsule()
                        .fill(index < litSegments ? color : Color.primary.opacity(0.12))
                        .frame(height: 4)
                }
            }
            .frame(maxWidth: 160)
            Text(isEmpty ? " " : strength.displayName)
                .font(.caption.weight(.medium))
                .foregroundStyle(isEmpty ? Color.secondary : color)
                .frame(minWidth: 64, alignment: .leading)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Password strength")
        .accessibilityValue(isEmpty ? "No password entered" : strength.displayName)
    }

    private var litSegments: Int {
        guard !isEmpty else { return 0 }
        switch strength {
        case .tooShort: return 1
        case .weak: return 2
        case .fair: return 3
        case .strong: return 4
        }
    }

    private var color: Color {
        switch strength {
        case .tooShort, .weak: return BrandColor.failure
        case .fair: return BrandColor.warning
        case .strong: return BrandColor.gain
        }
    }
}
