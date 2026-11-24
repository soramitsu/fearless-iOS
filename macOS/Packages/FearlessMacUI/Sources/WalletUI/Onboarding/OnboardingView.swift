import DesignSystem
import SwiftUI
import UniformTypeIdentifiers
import WalletCore

/// First launch in the main window: the brand welcome, then the setup steps
/// beside a brand panel.
struct OnboardingView: View {
    @Bindable var model: OnboardingModel

    var body: some View {
        Group {
            if model.mode == .firstRun, model.step == .welcome {
                WelcomeView(model: model)
            } else {
                HStack(spacing: 0) {
                    SetupSidePanel(model: model)
                        .frame(width: 280)
                    OnboardingStepView(model: model)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(nsColor: .windowBackgroundColor))
                }
            }
        }
        .ignoresSafeArea()
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            JSONDrop.handle(providers) { url in
                Task {
                    if model.step != .importJSON, model.step != .password, model.step != .biometrics {
                        await model.choose(.importJSON)
                    }
                    model.loadJSON(from: url)
                }
            }
        }
    }
}

/// Reads a dropped file URL and hands it over if it is a `.json` file.
enum JSONDrop {
    @MainActor
    static func handle(_ providers: [NSItemProvider], perform: @escaping @MainActor (URL) -> Void) -> Bool {
        guard let provider = providers.first(where: { $0.canLoadObject(ofClass: URL.self) }) else { return false }
        _ = provider.loadObject(ofClass: URL.self) { url, _ in
            guard let url, url.pathExtension.lowercased() == "json" else { return }
            Task { @MainActor in perform(url) }
        }
        return true
    }
}

/// The brand moment and the first choice: create or import.
struct WelcomeView: View {
    @Bindable var model: OnboardingModel

    @State private var showingImport = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            BrandBackdrop()
            VStack(spacing: 0) {
                Spacer(minLength: 40)
                ZStack {
                    SolarHalo(size: 236)
                    CrestMark(size: 132)
                        .foregroundStyle(.white)
                }
                Wordmark(height: 26)
                    .foregroundStyle(.white)
                    .padding(.top, 18)
                Text("Your keys. Every chain. One Mac.")
                    .font(.brandDisplay(17, weight: .medium))
                    .foregroundStyle(BrandPalette.textMuted)
                    .padding(.top, 14)
                Spacer(minLength: 28)
                Group {
                    if showingImport {
                        importChoices
                    } else {
                        firstChoices
                    }
                }
                .frame(maxWidth: 680)
                .padding(.horizontal, 40)
                if let error = model.errorMessage {
                    InlineMessage(error, kind: .error)
                        .padding(.top, 12)
                        .frame(maxWidth: 680)
                }
                Spacer(minLength: 28)
                Label("Keys are encrypted and stay on this Mac. No account, no tracking.", systemImage: "lock.shield")
                    .font(.footnote)
                    .foregroundStyle(BrandPalette.textMuted)
                    .padding(.bottom, 28)
            }
        }
        .environment(\.colorScheme, .dark)
        .animation(reduceMotion ? nil : BrandMotion.settle(BrandMotion.d255), value: showingImport)
    }

    private var firstChoices: some View {
        HStack(spacing: 16) {
            Button {
                Task { await model.choose(.create) }
            } label: {
                ChoiceLabel(title: "Create a New Wallet", detail: "Start fresh with a new recovery phrase.", symbol: "plus.circle.fill", onBrand: true)
            }
            .buttonStyle(ChoiceCardButtonStyle(prominent: true))
            .keyboardShortcut(.defaultAction)
            Button {
                showingImport = true
            } label: {
                ChoiceLabel(title: "I Already Have a Wallet", detail: "Import a phrase, a seed, a JSON backup or watch an address.", symbol: "arrow.down.circle.fill", onBrand: true)
            }
            .buttonStyle(ChoiceCardButtonStyle(prominent: false))
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var importChoices: some View {
        VStack(spacing: 12) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(OnboardingModel.Path.allCases.filter { $0 != .create }) { path in
                    Button {
                        Task { await model.choose(path) }
                    } label: {
                        ChoiceLabel(title: path.title, detail: path.detail, symbol: path.symbol, onBrand: true)
                    }
                    .buttonStyle(ChoiceCardButtonStyle(prominent: false))
                }
            }
            Button {
                showingImport = false
            } label: {
                Label("Back", systemImage: "chevron.left")
            }
            .buttonStyle(.link)
            .foregroundStyle(BrandPalette.textSoft)
            .keyboardShortcut(.cancelAction)
        }
    }
}

/// Title, explanation and symbol of a choice card.
struct ChoiceLabel: View {
    let title: String
    let detail: String
    let symbol: String
    let onBrand: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(onBrand ? AnyShapeStyle(.white) : AnyShapeStyle(BrandColor.accent))
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(onBrand ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(onBrand ? AnyShapeStyle(BrandPalette.textSoft) : AnyShapeStyle(.secondary))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }
}

/// The dark brand panel beside the setup steps: the mark and where the user is.
struct SetupSidePanel: View {
    let model: OnboardingModel

    var body: some View {
        ZStack(alignment: .topLeading) {
            BrandPalette.ink
            LinearGradient(colors: [BrandPalette.plum.opacity(0.85), BrandPalette.ink.opacity(0)], startPoint: .top, endPoint: .center)
            AsanohaPattern(cell: 28).opacity(0.05)
            VStack(alignment: .leading, spacing: 0) {
                HorizontalLockup(height: 30)
                    .foregroundStyle(.white)
                    .padding(.top, 64)
                Text(model.mode == .firstRun ? "Set up Fearless" : "Add a wallet")
                    .font(.brandDisplay(22, weight: .bold))
                    .foregroundStyle(BrandPalette.text)
                    .padding(.top, 36)
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(model.outline.enumerated()), id: \.offset) { index, step in
                        OutlineRow(number: index + 1, title: step.title, state: state(of: step, at: index))
                    }
                }
                .padding(.top, 22)
                Spacer()
                Label("Encrypted on this Mac", systemImage: "lock.fill")
                    .font(.footnote)
                    .foregroundStyle(BrandPalette.textMuted)
                    .padding(.bottom, 24)
            }
            .padding(.horizontal, 28)
        }
        .environment(\.colorScheme, .dark)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Setup progress")
    }

    private enum RowState { case done, current, upcoming }

    private func state(of step: OnboardingModel.Step, at index: Int) -> RowState {
        let outline = model.outline
        let currentIndex = outline.firstIndex(of: model.step) ?? (model.step == .biometrics ? 0 : -1)
        if model.step == .biometrics, step == .password { return .done }
        if index < currentIndex { return .done }
        if index == currentIndex { return .current }
        return .upcoming
    }

    private struct OutlineRow: View {
        let number: Int
        let title: String
        let state: RowState

        var body: some View {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(state == .current ? BrandPalette.gold : (state == .done ? BrandPalette.gold.opacity(0.25) : Color.white.opacity(0.10)))
                        .frame(width: 22, height: 22)
                    if state == .done {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(BrandPalette.gold)
                    } else {
                        Text("\(number)")
                            .font(.caption.weight(.bold).monospacedDigit())
                            .foregroundStyle(state == .current ? BrandPalette.ink : BrandPalette.textMuted)
                    }
                }
                Text(title)
                    .font(.callout.weight(state == .current ? .semibold : .regular))
                    .foregroundStyle(state == .upcoming ? BrandPalette.textMuted : BrandPalette.text)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Step \(number): \(title)")
            .accessibilityValue(state == .done ? "Done" : (state == .current ? "Current step" : "Not started"))
        }
    }
}
