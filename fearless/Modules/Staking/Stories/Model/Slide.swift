struct Slide {
    let description: String
    let urlString: String?
}

struct Story {
    let icon: String
    let title: String
    let slides: [Slide]
}

struct StoriesModel {
    let stories: [Story]

    init(stories: [Story]) {
        self.stories = stories
    }
}
