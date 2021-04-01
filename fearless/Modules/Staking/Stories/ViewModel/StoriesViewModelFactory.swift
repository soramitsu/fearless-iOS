import Foundation

protocol StoriesViewModelFactoryProtocol {
    func createStoryViewModel(from story: Story) -> [SlideViewModel]
}

class StoriesViewModelFactory: StoriesViewModelFactoryProtocol {
    func createStoryViewModel(from story: Story) -> [SlideViewModel] {
        let slides = story.slides.map { slide in
            SlideViewModel(
                title: "\(story.icon) \(story.title)",
                content: slide.description)
         }
        return slides
    }
}
