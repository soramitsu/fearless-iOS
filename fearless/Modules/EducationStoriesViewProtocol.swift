protocol EducationStoriesViewProtocol: ControllerBackedProtocol {
    func didReceive(state: EducationStoriesViewState)
}

protocol EducationStoriesPresenterProtocol: AnyObject {
    func didLoad(view: EducationStoriesViewProtocol)
    func didCloseStories()
}

protocol EducationStoriesRouterProtocol: AnyObject {
    func showMain()
}
