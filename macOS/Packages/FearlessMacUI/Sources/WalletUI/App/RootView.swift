import DesignSystem
import SwiftUI
import WalletCore

/// The main window's content: launch, onboarding, lock or the wallet.
struct RootView: View {
    @Bindable var app: AppModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            switch app.route {
            case .launching:
                LaunchView()
            case .onboarding:
                if let model = app.onboarding {
                    OnboardingView(model: model)
                } else {
                    LaunchView()
                }
            case .locked:
                LockView(model: app.lockModel)
            case .main:
                MainView(app: app)
            }
        }
        .animation(reduceMotion ? nil : BrandMotion.settle(BrandMotion.d360), value: app.route)
        .overlay(alignment: .bottom) {
            if let toast = app.toast {
                ToastView(toast: toast)
                    .padding(.bottom, 24)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(reduceMotion ? nil : BrandMotion.settle(BrandMotion.d255), value: app.toast)
        .environment(\.balancesHidden, app.settings.balancesHidden)
        .tint(BrandColor.accent)
        .background(WindowChrome(style: chromeStyle))
        // Brand screens are always dark; everything else follows Settings
        // (nil follows the system).
        .preferredColorScheme(chromeStyle == .brand ? .dark : app.settings.appearance.colorScheme)
        .onChange(of: app.settings.appearance) { _, _ in app.applyAppearance() }
    }

    private var chromeStyle: WindowChrome.Style {
        switch app.route {
        case .launching, .locked:
            return .brand
        case .onboarding:
            return app.onboarding?.step == .welcome && app.onboarding?.mode == .firstRun ? .brand : .immersive
        case .main:
            return .standard
        }
    }
}

/// Shown for a moment while the vault reports its state.
struct LaunchView: View {
    var body: some View {
        ZStack {
            BrandBackdrop()
            CrestMark(size: 120)
                .foregroundStyle(.white)
        }
        .environment(\.colorScheme, .dark)
    }
}

/// A short confirmation at the bottom of the window.
struct ToastView: View {
    let toast: Toast

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: toast.symbol)
                .foregroundStyle(.secondary)
            Text(toast.text)
                .font(.callout.weight(.medium))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background {
            if reduceTransparency {
                Capsule().fill(Color(nsColor: .windowBackgroundColor))
            } else {
                Capsule().fill(.regularMaterial)
            }
        }
        .overlay(Capsule().strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.18), radius: 10, y: 3)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isStaticText)
    }
}
