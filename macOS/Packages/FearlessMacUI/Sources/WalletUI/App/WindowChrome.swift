import AppKit
import SwiftUI

/// Adjusts the hosting window's title bar for the screen it shows. Brand
/// screens (welcome, lock) and the setup steps put their content under a
/// transparent title bar without a title; the main window uses the standard
/// title bar.
///
/// Light or dark is not set here: SwiftUI owns the window's appearance
/// (`preferredColorScheme` in `RootView`). Setting `NSWindow.appearance`
/// from this view as well made the two fight over it in an endless update
/// loop.
struct WindowChrome: NSViewRepresentable {
    enum Style: Equatable {
        /// Full-window brand surface: always dark, no title.
        case brand
        /// Setup steps: content under a transparent title bar.
        case immersive
        /// The main window.
        case standard

        var hidesTitleBar: Bool { self != .standard }
    }

    let style: Style

    func makeNSView(context: Context) -> NSView {
        let view = ChromeView()
        view.style = style
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let view = nsView as? ChromeView, view.style != style else { return }
        view.style = style
        view.apply()
    }

    final class ChromeView: NSView {
        var style: Style = .standard

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            apply()
        }

        /// Writes only the properties that differ, so nothing is invalidated needlessly.
        func apply() {
            guard let window else { return }
            let hidden = style.hidesTitleBar
            let visibility: NSWindow.TitleVisibility = hidden ? .hidden : .visible
            if window.titleVisibility != visibility { window.titleVisibility = visibility }
            if window.titlebarAppearsTransparent != hidden { window.titlebarAppearsTransparent = hidden }
            if window.isMovableByWindowBackground != hidden { window.isMovableByWindowBackground = hidden }
        }
    }
}
