// Copied from FearlessMacUI/Sources/FearlessMacSnapshots (executable targets cannot be imported).
import AppKit
import DesignSystem
import SwiftUI

/// A window that may sit outside every screen and draws as the key window,
/// so controls render in their active state without the tool taking focus.
final class OffscreenWindow: NSWindow {
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
    override var isKeyWindow: Bool { true }
    override var isMainWindow: Bool { true }
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    // AppKit asks these when it decides whether to draw controls as active.
    @objc var hasKeyAppearance: Bool { true }
    @objc var hasMainAppearance: Bool { true }
}

/// Renders SwiftUI views in real, off-screen AppKit windows and captures
/// them. Sidebars, inspectors and toolbars live in system material layers
/// that `cacheDisplay` cannot draw, so the window server's own picture of
/// the window is used first; `bitmapImageRepForCachingDisplay` with
/// `cacheDisplay` is the fallback when that is unavailable.
@MainActor
enum SnapshotRenderer {
    /// Far outside any display, so nothing ever flashes on the user's screen.
    private static let parkingOrigin = CGPoint(x: -30_000, y: -30_000)

    static func settle(_ seconds: TimeInterval) async {
        try? await Task.sleep(for: .seconds(seconds))
    }

    /// A titled window with the unified toolbar, like the app's main window.
    static func captureWindow(_ view: AnyView, size: CGSize, title: String, settleSeconds: TimeInterval) async -> CGImage? {
        let window = OffscreenWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.title = title
        let host = NSHostingView(rootView: view.environment(\.staticRendering, true))
        host.sceneBridgingOptions = [.all]
        // The window keeps the requested size whatever the content would prefer.
        host.sizingOptions = []
        window.contentView = host
        window.setFrame(NSRect(origin: parkingOrigin, size: size), display: true)
        return await capture(window, settleSeconds: settleSeconds)
    }

    /// A bare panel sized to its content (sheets, the menu bar panel).
    static func capturePanel(_ view: AnyView, settleSeconds: TimeInterval) async -> CGImage? {
        let host = NSHostingView(rootView: view.environment(\.staticRendering, true))
        let window = OffscreenWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 300), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.backgroundColor = .windowBackgroundColor
        window.contentView = host
        window.setFrame(NSRect(origin: parkingOrigin, size: NSSize(width: 400, height: 300)), display: true)
        window.orderFrontRegardless()
        await settle(0.3)
        let fitting = host.fittingSize
        window.setFrame(NSRect(origin: parkingOrigin, size: fitting), display: true)
        return await capture(window, settleSeconds: settleSeconds)
    }

    private static func capture(_ window: NSWindow, settleSeconds: TimeInterval) async -> CGImage? {
        window.orderFrontRegardless()
        NotificationCenter.default.post(name: NSWindow.didBecomeKeyNotification, object: window)
        NotificationCenter.default.post(name: NSWindow.didBecomeMainNotification, object: window)
        await settle(settleSeconds)
        window.displayIfNeeded()
        var image = CGWindowListCreateImage(.null, .optionIncludingWindow, CGWindowID(window.windowNumber), [.boundsIgnoreFraming, .bestResolution])
        if image == nil || image?.width == 0 {
            image = cacheDisplayImage(of: window)
        }
        window.orderOut(nil)
        window.contentView = nil
        window.close()
        return image
    }

    private static func cacheDisplayImage(of window: NSWindow) -> CGImage? {
        guard let view = window.contentView?.superview ?? window.contentView,
              let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds)
        else { return nil }
        view.cacheDisplay(in: view.bounds, to: rep)
        return rep.cgImage
    }

    /// A sheet as it appears over its window: the window dimmed, the sheet
    /// centred with rounded corners and a shadow.
    static func composite(sheet: CGImage, over backdrop: CGImage, scale: CGFloat) -> CGImage? {
        let width = backdrop.width
        let height = backdrop.height
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        let bounds = CGRect(x: 0, y: 0, width: width, height: height)
        context.draw(backdrop, in: bounds)
        context.setBlendMode(.sourceAtop)
        context.setFillColor(CGColor(gray: 0, alpha: 0.28))
        context.fill(bounds)
        context.setBlendMode(.normal)

        let sheetRect = CGRect(
            x: (CGFloat(width) - CGFloat(sheet.width)) / 2,
            y: (CGFloat(height) - CGFloat(sheet.height)) / 2,
            width: CGFloat(sheet.width),
            height: CGFloat(sheet.height)
        ).integral
        let radius = 14 * scale
        let path = CGPath(roundedRect: sheetRect, cornerWidth: radius, cornerHeight: radius, transform: nil)
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: -10 * scale), blur: 34 * scale, color: CGColor(gray: 0, alpha: 0.45))
        context.setFillColor(CGColor(gray: 0.5, alpha: 1))
        context.addPath(path)
        context.fillPath()
        context.restoreGState()
        context.saveGState()
        context.addPath(path)
        context.clip()
        context.draw(sheet, in: sheetRect)
        context.restoreGState()
        context.addPath(path)
        context.setStrokeColor(CGColor(gray: 0.5, alpha: 0.35))
        context.setLineWidth(scale)
        context.strokePath()
        return context.makeImage()
    }

    static func write(_ image: CGImage, to url: URL) throws {
        let rep = NSBitmapImageRep(cgImage: image)
        guard let data = rep.representation(using: .png, properties: [:]) else {
            throw CocoaError(.fileWriteUnknown)
        }
        try data.write(to: url, options: .atomic)
    }
}
