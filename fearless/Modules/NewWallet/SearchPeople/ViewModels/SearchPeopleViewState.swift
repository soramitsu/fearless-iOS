import Foundation

enum SearchPeopleViewState {
    case empty
    case loaded(SearchPeopleViewModel)
    case error(Error)
}
