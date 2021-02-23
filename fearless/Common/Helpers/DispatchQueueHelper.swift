import Foundation

func dispatchInQueueWhenPossible(_ queue: DispatchQueue?, block: @escaping () -> Void ) {
    if let queue = queue {
        queue.async(execute: block)
    } else {
        block()
    }
}
