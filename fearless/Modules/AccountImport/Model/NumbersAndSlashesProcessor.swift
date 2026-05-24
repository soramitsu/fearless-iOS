import FearlessFoundation

final class NumbersAndSlashesProcessor: TextProcessing {
    func process(text: String) -> String {
        text.filter { $0.isNumber || $0 == "/" }
    }
}
