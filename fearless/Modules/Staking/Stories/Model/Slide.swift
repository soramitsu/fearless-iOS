import Foundation
import UIKit

struct Slide : Equatable, Hashable {
    var id: Double
    var image: UIImage?
    var title: String
    var titleColor: UIColor
    var description: String
    var descColor: UIColor
    var buttonText: String?
    var buttonColor: UIColor = .lightGray
    var buttonLink: URL?
    var background: UIColor

    init(id: Double,
         title: String,
         titleColor: UIColor = .black,
         description: String,
         descColor: UIColor = .darkGray,
         buttonText: String = "",
         buttonColor: UIColor = .lightGray,
         buttonLink: URL? = nil,
         imageName: String,
         background: UIColor = .clear) {
        self.id = id
        self.title = title
        self.titleColor = titleColor
        self.description = description
        self.descColor = descColor
        self.buttonText = buttonText
        self.buttonColor = buttonColor
        self.buttonLink = buttonLink
        self.image = UIImage(named: imageName)
        self.background = background
    }
}

struct Story {
    let icon: String
    let title: String
    let slides: [Slide]

    init(icon: String,
         title: String,
         slides: [Slide]) {
        self.icon = icon
        self.title = title
        self.slides = slides
    }
}

struct StoriesModel {
    let stories: [Story]

    init(stories: [Story]) {
        self.stories = stories
    }
}
