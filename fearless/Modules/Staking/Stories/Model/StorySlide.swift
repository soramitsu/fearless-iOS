struct StorySlide {
    let description: String
    let urlString: String?
}

struct Story {
    let icon: String
    let title: String
    let slides: [StorySlide]
}

struct StoriesModel {
    let stories: [Story]

    init(stories: [Story]) {
        self.stories = stories
    }
}
