import UIKit

public final class SoramitsuActivityIndicatorViewConfiguration<Type: SoramitsuActivityIndicatorView>: SoramitsuViewConfiguration<Type> {

	private struct Constants {
		static var lineWidth: CGFloat { return 3 }
		static var size: CGSize { return .init(width: 42, height: 42) }
	}

    public var indicatorColor = SoramitsuColor.bgSurface {
		didSet {
			owner?.indicatorLayer.strokeColor = style.palette.color(indicatorColor).cgColor
		}
	}

	public var lineWidth = Constants.lineWidth {
		didSet {
			owner?.indicatorLayer.lineWidth = lineWidth
		}
	}

	public var size = Constants.size {
		didSet {
			owner?.indicatorLayer.path = UIBezierPath(ovalIn: CGRect(origin: CGPoint(x: lineWidth, y: lineWidth),
																	 size: CGSize(width: size.width - 2 * lineWidth,
																				  height: size.height - 2 * lineWidth))).cgPath
			owner?.invalidateIntrinsicContentSize()
		}
	}

	public override func styleDidChange(options: UpdateOptions) {
		if options.contains(.palette) {
			retrigger(self, \.indicatorColor)
		}
	}

	/// Первоначальная настройка индикатора
	override func configureOwner() {
		super.configureOwner()
		retrigger(self, \.size)
		retrigger(self, \.indicatorColor)
		retrigger(self, \.lineWidth)
	}
}
