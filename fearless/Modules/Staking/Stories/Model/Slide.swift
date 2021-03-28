import Foundation
import UIKit

struct Slide {
    var description: String
    var buttonLink: URL?

    init(description: String,
         buttonLink: URL? = nil) {
        self.description = description
        self.buttonLink = buttonLink
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
