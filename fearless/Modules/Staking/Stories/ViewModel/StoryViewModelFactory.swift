import Foundation

protocol StoryViewModelFactoryProtocol {
    func createStoryViewModel(from story: Story) -> [SlideViewModel]
}

class StoryViewModelFactory: StoryViewModelFactoryProtocol {
    func createStoryViewModel(from story: Story) -> [SlideViewModel] {
        var slides: [SlideViewModel] = []

        story.slides.forEach { slide in
            slides.append(SlideViewModel(title: "\(story.icon) \(story.title)",
                                         content: slide.description))
        }

        return slides
    }
}
