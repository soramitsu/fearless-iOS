import UIKit

public final class ImageButtonConfiguration<Type: ImageButton>: SoramitsuBaseButtonConfiguration<Type,
                                                                        ImageButtonConfiguration>, Statable {
    public var image: UIImage? {
        didSet {
            owner?.setImage(image, for: .normal)
        }
    }

	init(style: SoramitsuStyle) {
		super.init(style: style, stater: SoramitsuStateDecorator(state: .default))
		stater.g = self
	}
}
