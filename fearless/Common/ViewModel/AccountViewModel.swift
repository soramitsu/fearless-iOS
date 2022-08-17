import FearlessUtils
import UIKit

struct AccountViewModel {
    let title: String
    let name: String
    let icon: DrawableIcon?
    let image: UIImage?

    init(
        title: String,
        name: String,
        icon: DrawableIcon?,
        image: UIImage? = nil
    ) {
        self.title = title
        self.name = name
        self.icon = icon
        self.image = image
    }
}
