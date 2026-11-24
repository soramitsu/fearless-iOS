import SwiftUI

/// Centred placeholder for a list or pane with nothing to show.
public struct EmptyStateView<Actions: View>: View {
    private let title: String
    private let message: String
    private let systemImage: String
    private let actions: Actions

    public init(_ title: String, message: String, systemImage: String, @ViewBuilder actions: () -> Actions) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
        self.actions = actions()
    }

    public var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(message)
        } actions: {
            actions
        }
    }
}

public extension EmptyStateView where Actions == EmptyView {
    init(_ title: String, message: String, systemImage: String) {
        self.init(title, message: message, systemImage: systemImage) { EmptyView() }
    }
}

/// Centred error with a retry button.
public struct ErrorStateView: View {
    private let title: String
    private let message: String
    private let retry: (() -> Void)?

    public init(_ title: String = "Something went wrong", message: String, retry: (() -> Void)? = nil) {
        self.title = title
        self.message = message
        self.retry = retry
    }

    public var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            if let retry {
                Button("Try Again", action: retry)
            }
        }
    }
}

/// Centred loader with a caption, for a pane that is fetching its content.
public struct LoadingStateView: View {
    private let caption: String

    public init(_ caption: String) {
        self.caption = caption
    }

    public var body: some View {
        VStack(spacing: 12) {
            CometLoader(size: 44)
            Text(caption).font(.callout).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(caption)
    }
}
