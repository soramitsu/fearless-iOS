// The MIT License (MIT)
//
// Copyright (c) 2021 Alexander Grebenyuk (github.com/kean).

import UIKit

// swiftlint:disable all
public extension UIView {
    static func vStack(
        alignment: UIStackView.Alignment = .fill,
        distribution: UIStackView.Distribution = .fill,
        spacing: CGFloat = 0,
        margins: UIEdgeInsets? = nil,
        _ views: [UIView]
    ) -> UIStackView {
        makeStackView(axis: .vertical, alignment: alignment, distribution: distribution, spacing: spacing, margins: margins, views)
    }

    static func hStack(
        alignment: UIStackView.Alignment = .fill,
        distribution: UIStackView.Distribution = .fill,
        spacing: CGFloat = 0,
        margins: UIEdgeInsets? = nil,
        _ views: [UIView]
    ) -> UIStackView {
        makeStackView(axis: .horizontal, alignment: alignment, distribution: distribution, spacing: spacing, margins: margins, views)
    }
}

public extension UIView {
    /// Makes a fixed space along the axis of the containing stack view.
    static func spacer(length: CGFloat) -> UIView {
        Spacer(length: length, isFixed: true)
    }

    /// Makes a flexible space along the axis of the containing stack view.
    static func spacer(minLength: CGFloat = 0) -> UIView {
        Spacer(length: minLength, isFixed: false)
    }
}

// MARK: - Private

private extension UIView {
    static func makeStackView(axis: NSLayoutConstraint.Axis, alignment: UIStackView.Alignment, distribution: UIStackView.Distribution, spacing: CGFloat, margins: UIEdgeInsets?, _ views: [UIView]) -> UIStackView {
        let stack = UIStackView(arrangedSubviews: views)
        stack.axis = axis
        stack.alignment = alignment
        stack.distribution = distribution
        stack.spacing = spacing
        if let margins = margins {
            stack.isLayoutMarginsRelativeArrangement = true
            stack.layoutMargins = margins
        }
        return stack
    }
}

private final class Spacer: UIView {
    private let length: CGFloat
    private let isFixed: Bool
    private var axis: NSLayoutConstraint.Axis?
    private var observer: AnyObject?
    private var _constraints: [NSLayoutConstraint] = []

    init(length: CGFloat, isFixed: Bool) {
        self.length = length
        self.isFixed = isFixed
        super.init(frame: .zero)
    }

    override func willMove(toSuperview newSuperview: UIView?) {
        super.willMove(toSuperview: newSuperview)

        guard let stackView = newSuperview as? UIStackView else {
            axis = nil
            setNeedsUpdateConstraints()
            return
        }

        axis = stackView.axis
        observer = stackView.observe(\.axis, options: [.initial, .new]) { [weak self] _, axis in
            self?.axis = axis.newValue
            self?.setNeedsUpdateConstraints()
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override fileprivate func updateConstraints() {
        super.updateConstraints()

        NSLayoutConstraint.deactivate(_constraints)

        let attributes: [NSLayoutConstraint.Attribute]
        switch axis {
        case .horizontal: attributes = [.width]
        case .vertical: attributes = [.height]
        default: attributes = [.height, .width] // Not really an expected use-case
        }
        _constraints = attributes.map {
            let constraint = NSLayoutConstraint(item: self, attribute: $0, relatedBy: isFixed ? .equal : .greaterThanOrEqual, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: length)
            constraint.priority = UILayoutPriority(999)
            return constraint
        }

        NSLayoutConstraint.activate(_constraints)
    }
}

// MARK: - Preview

#if canImport(SwiftUI) && DEBUG
    import SwiftUI

    @available(iOS 13.0, *)
    struct ExampleView: UIViewControllerRepresentable {
        let closure: (UIView) -> Void

        func makeUIViewController(context _: Context) -> some UIViewController {
            let vc = UIViewController()
            closure(vc.view)
            return vc
        }

        func updateUIViewController(_: UIViewControllerType, context _: Context) {}
    }

    @available(iOS 13.0, *)
    struct ExampleView_Preview: PreviewProvider {
        static var previews: some View {
            Group {
                // WARNING
                // !!!!!!!
                //
                // - This won't work unless you go to Package.swift and change required version to iOS 13

                ExampleView { container in
                    let titleLabel = UILabel().then {
                        $0.font = .preferredFont(forTextStyle: .headline)
                        $0.text = "Explore the render loop"
                        $0.numberOfLines = 0
                    }

                    let subtitleLabel = UILabel().then {
                        $0.text = "Explore how you can improve the performance of your app's user interface by identifying scrolling and animation hitches in your app."
                        $0.numberOfLines = 0
                    }

                    let star = UIImageView(systemName: "star.fill", textStyle: .title1, color: .systemYellow)
                    let clock = UIImageView(systemName: "clock", textStyle: .caption1, color: .label)

                    let timeLabel = UILabel().then {
                        $0.font = .preferredFont(forTextStyle: .caption1)
                        $0.text = "20:21"
                    }

                    let stack: UIView = .hStack(alignment: .center, margins: .all(16), [
                        .vStack(spacing: 8, [
                            titleLabel,
                            .hStack(spacing: 4, [clock, timeLabel, .spacer()]),
                            subtitleLabel
                        ]),
                        .spacer(minLength: 16),
                        star
                    ])

                    container.addSubview(stack)
                    stack.centerInSuperview()
                    stack.pinToHorizontalEdges()

                    // stack.addBorderRecursively()
                }
            }
        }
    }

    // MARK: - UIEdgeInsets Extensions (Private)

    private extension UIEdgeInsets {
        static func all(_ value: CGFloat) -> UIEdgeInsets {
            UIEdgeInsets(top: value, left: value, bottom: value, right: value)
        }

        init(v: CGFloat, h: CGFloat) {
            self = UIEdgeInsets(top: v, left: h, bottom: v, right: h)
        }
    }

    // MARK: - Helpers (Private)

    private extension UIView {
        @available(iOS 13.0, *)
        func addBorderRecursively() {
            var colors: [UIColor] = []
            func resetColors() {
                colors = [.systemRed, .systemBlue, .systemGreen, .systemOrange, .systemTeal, .systemPink, .systemPurple, .systemIndigo].reversed()
            }
            func addBorder(view: UIView) {
                if colors.isEmpty {
                    resetColors()
                }
                view.border(colors.removeFirst(), width: 1)
                for subview in view.subviews {
                    addBorder(view: subview)
                }
            }
            addBorder(view: self)
        }

        @discardableResult func border(_ color: UIColor, width: CGFloat) -> UIView {
            layer.borderColor = color.cgColor
            layer.borderWidth = width
            return self
        }

        func pinToHorizontalEdges() {
            translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                leftAnchor.constraint(equalTo: superview!.leftAnchor),
                rightAnchor.constraint(equalTo: superview!.rightAnchor)
            ])
        }

        func centerInSuperview() {
            translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                centerXAnchor.constraint(equalTo: superview!.centerXAnchor),
                centerYAnchor.constraint(equalTo: superview!.centerYAnchor),
                leftAnchor.constraint(greaterThanOrEqualTo: superview!.leftAnchor),
                rightAnchor.constraint(lessThanOrEqualTo: superview!.rightAnchor)
            ])
        }
    }

    @available(iOS 13.0, *)
    private extension UIImageView {
        convenience init(systemName: String, textStyle: UIFont.TextStyle, color: UIColor?) {
            let image = UIImage(systemName: systemName, withConfiguration: UIImage.SymbolConfiguration(textStyle: textStyle))
            self.init(image: image)
            tintColor = color
        }
    }

    private protocol Then {}

    extension Then where Self: AnyObject {
        func then(_ closure: (Self) throws -> Void) rethrows -> Self {
            try closure(self)
            return self
        }
    }

    extension NSObject: Then {}

#endif
