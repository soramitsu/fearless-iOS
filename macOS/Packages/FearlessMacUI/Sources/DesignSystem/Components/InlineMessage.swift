import SwiftUI

/// A one-line notice inside a form or above a list: an icon, the message and
/// an optional action. Used for warnings, errors and per-network failures.
public struct InlineMessage<Accessory: View>: View {
    public enum Kind: Sendable {
        case info, warning, error, success

        var color: Color {
            switch self {
            case .info: return .secondary
            case .warning: return BrandColor.warning
            case .error: return BrandColor.failure
            case .success: return BrandColor.final
            }
        }

        var symbol: String {
            switch self {
            case .info: return "info.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .error: return "exclamationmark.octagon.fill"
            case .success: return "checkmark.seal.fill"
            }
        }

        var spoken: String {
            switch self {
            case .info: return "Note"
            case .warning: return "Warning"
            case .error: return "Error"
            case .success: return "Done"
            }
        }
    }

    private let kind: Kind
    private let text: String
    private let boxed: Bool
    private let accessory: Accessory

    public init(_ text: String, kind: Kind, boxed: Bool = false, @ViewBuilder accessory: () -> Accessory) {
        self.text = text
        self.kind = kind
        self.boxed = boxed
        self.accessory = accessory()
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: kind.symbol)
                .foregroundStyle(kind.color)
                .accessibilityHidden(true)
            Text(text)
                .foregroundStyle(boxed ? Color.primary : kind.color)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel("\(kind.spoken): \(text)")
            Spacer(minLength: 8)
            accessory
        }
        .font(.callout)
        .padding(boxed ? 10 : 0)
        .background {
            if boxed {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(kind.color.opacity(0.10))
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(kind.color.opacity(0.35), lineWidth: 0.5))
            }
        }
    }
}

public extension InlineMessage where Accessory == EmptyView {
    init(_ text: String, kind: Kind, boxed: Bool = false) {
        self.init(text, kind: kind, boxed: boxed) { EmptyView() }
    }
}
