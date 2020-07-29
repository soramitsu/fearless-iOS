import Foundation

protocol SelectionListViewModelObserver: class {
    func didChangeSelection()
}

protocol SelectableViewModelProtocol: class {
    var isSelected: Bool { get }

    func addObserver(_ observer: SelectionListViewModelObserver)
    func removeObserver(_ observer: SelectionListViewModelObserver)
}

private struct Constants {
    static var isSelectedKey = "co.jp.fearless.selectable.selected"
    static var observersKey = "co.jp.fearless.observers"
}

private struct Observation {
    weak var observer: SelectionListViewModelObserver?
}

extension SelectableViewModelProtocol {
    var isSelected: Bool {
        get {
            return objc_getAssociatedObject(self, &Constants.isSelectedKey) as? Bool ?? false
        }

        set {

            if newValue != isSelected {
                objc_setAssociatedObject(self,
                                         &Constants.isSelectedKey,
                                         newValue,
                                         .OBJC_ASSOCIATION_COPY)

                observers.forEach {
                    $0.observer?.didChangeSelection()
                }
            }
        }
    }

    private var observers: [Observation] {
        get {
            return objc_getAssociatedObject(self, &Constants.observersKey) as? [Observation] ?? []
        }

        set {
            objc_setAssociatedObject(self,
                                     &Constants.observersKey,
                                     newValue,
                                     .OBJC_ASSOCIATION_COPY)
        }
    }

    func addObserver(_ observer: SelectionListViewModelObserver) {
        var observers = self.observers.filter { $0.observer != nil }

        if !observers.contains(where: { $0.observer === observer }) {
            observers.append(Observation(observer: observer))
            self.observers = observers
        }
    }

    func removeObserver(_ observer: SelectionListViewModelObserver) {
        let observers = self.observers.filter { $0.observer != nil && $0.observer !== observer }
        self.observers = observers
    }
}
