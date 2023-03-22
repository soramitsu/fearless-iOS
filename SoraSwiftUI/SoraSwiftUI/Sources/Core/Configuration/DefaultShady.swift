import UIKit

struct DefaultShady: Shady {
	let none = ShadowData(color: nil,
						  offset: .zero,
						  radius: .zero,
						  opacity: .zero)
    let `default` = ShadowData(color: UIColor(red: 153 / 255.0, green: 153 / 255.0, blue: 153 / 255.0, alpha: 0.24).cgColor,
							   offset: CGSize(width: 0.0, height: 10.0),
							   radius: 20,
							   opacity: 1)
    let extraSmall = ShadowData(color: UIColor(white: 0, alpha: 0.08).cgColor,
                           offset: CGSize(width: 0, height: 0),
                           radius: 16,
                           opacity: 1)
	let small = ShadowData(color: UIColor(white: 0, alpha: 0.08).cgColor,
						   offset: CGSize(width: 0, height: 12),
						   radius: 16,
						   opacity: 1)
}
