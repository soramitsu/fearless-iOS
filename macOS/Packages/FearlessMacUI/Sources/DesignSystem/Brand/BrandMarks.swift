import AppKit
import SwiftUI

/// The kit's vector masters, loaded once. The SVG files are copied byte for
/// byte from the brand kit; nothing is redrawn.
@MainActor
enum BrandImage {
    static let crest = load("fearless-crest")
    static let crestSmall = load("fearless-crest-small")
    static let wordmark = load("fearless-wordmark")
    static let lockupStacked = load("fearless-lockup-stacked")
    static let lockupHorizontal = load("fearless-lockup-horizontal")

    private static func load(_ name: String) -> NSImage? {
        guard let url = DesignSystemResources.url(forResource: name, withExtension: "svg", subdirectory: "Brand"),
              let image = NSImage(contentsOf: url)
        else { return nil }
        image.isTemplate = true
        return image
    }
}

/// A brand mark drawn in the current foreground style.
private struct TemplateMark: View {
    let image: NSImage?
    let fallbackAspect: CGFloat

    var body: some View {
        if let image {
            Image(nsImage: image)
                .resizable()
                .renderingMode(.template)
                .interpolation(.high)
                .aspectRatio(image.size.width / max(image.size.height, 1), contentMode: .fit)
        } else {
            Color.clear.aspectRatio(fallbackAspect, contentMode: .fit)
        }
    }
}

/// The Yatagarasu crest. Uses the small crest below 64 points, as the
/// identity rules require. Tint it with `foregroundStyle`: white on dark
/// surfaces, ink on pale ones, gold on plum.
public struct CrestMark: View {
    private let size: CGFloat

    public init(size: CGFloat) {
        self.size = size
    }

    public var body: some View {
        TemplateMark(image: size < 64 ? BrandImage.crestSmall : BrandImage.crest, fallbackAspect: 1)
            .frame(width: size, height: size)
            .accessibilityElement()
            .accessibilityLabel("Fearless")
            .accessibilityAddTraits(.isImage)
    }
}

/// The crest in the app icon's gradient circle, for round slots.
public struct CrestBadge: View {
    private let size: CGFloat

    public init(size: CGFloat) {
        self.size = size
    }

    public var body: some View {
        ZStack {
            Circle().fill(BrandPalette.iconGradient(diameter: size))
            TemplateMark(image: size < 64 ? BrandImage.crestSmall : BrandImage.crest, fallbackAspect: 1)
                .foregroundStyle(.white)
                .frame(width: size * 0.78857, height: size * 0.78857)
        }
        .frame(width: size, height: size)
        .accessibilityElement()
        .accessibilityLabel("Fearless")
        .accessibilityAddTraits(.isImage)
    }
}

/// The FEARLESS wordmark at a given cap height.
public struct Wordmark: View {
    private let height: CGFloat

    public init(height: CGFloat) {
        self.height = height
    }

    public var body: some View {
        TemplateMark(image: BrandImage.wordmark, fallbackAspect: 675.5 / 102)
            .frame(height: height)
            .accessibilityElement()
            .accessibilityLabel("Fearless")
            .accessibilityAddTraits(.isImage)
    }
}

/// Crest over wordmark, for full-page brand screens.
public struct StackedLockup: View {
    private let width: CGFloat

    public init(width: CGFloat) {
        self.width = width
    }

    public var body: some View {
        TemplateMark(image: BrandImage.lockupStacked, fallbackAspect: 640 / 505.3)
            .frame(width: width)
            .accessibilityElement()
            .accessibilityLabel("Fearless")
            .accessibilityAddTraits(.isImage)
    }
}

/// Crest beside wordmark, for headers.
public struct HorizontalLockup: View {
    private let height: CGFloat

    public init(height: CGFloat) {
        self.height = height
    }

    public var body: some View {
        TemplateMark(image: BrandImage.lockupHorizontal, fallbackAspect: 694.31 / 150)
            .frame(height: height)
            .accessibilityElement()
            .accessibilityLabel("Fearless")
            .accessibilityAddTraits(.isImage)
    }
}

public extension NSImage {
    /// The small crest as a template image for the menu bar.
    @MainActor
    static func fearlessMenuBarCrest(pointSize: CGFloat = 18) -> NSImage? {
        guard let source = BrandImage.crestSmall, let copy = source.copy() as? NSImage else { return nil }
        copy.size = NSSize(width: pointSize, height: pointSize)
        copy.isTemplate = true
        return copy
    }
}

/// The app icon drawn from the brand marks, for tools that run without an
/// app bundle (the demo). The shipping app's icon lives in its asset catalog.
@MainActor
public enum BrandIcon {
    public static func applicationIcon(size: CGFloat = 512) -> NSImage? {
        let content = ZStack {
            RoundedRectangle(cornerRadius: size * 0.225, style: .continuous)
                .fill(BrandPalette.iconGradient(diameter: size))
            CrestMark(size: size * 0.66)
                .foregroundStyle(.white)
        }
        .frame(width: size * 0.82, height: size * 0.82)
        .frame(width: size, height: size)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        return renderer.nsImage
    }
}

/// The app's accent colour. The shipping app declares it as `AccentColor` in
/// its asset catalog, which colours sidebar selection, default buttons and
/// focus rings. Tools that run without a bundle (the demo, snapshots) have
/// no catalog, so they ask for the system's pink accent for this process
/// only, unless the user has chosen an accent colour themselves.
public enum ToolAccent {
    public static func applyIfUnset() {
        let key = "AppleAccentColor"
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: key) == nil else { return }
        var arguments = defaults.volatileDomain(forName: UserDefaults.argumentDomain)
        arguments[key] = 6
        defaults.setVolatileDomain(arguments, forName: UserDefaults.argumentDomain)
    }
}
