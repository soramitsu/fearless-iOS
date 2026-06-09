enum TimeFormatter {
    static func minutesSecondsString(from seconds: Int) -> String {
        let minutes: Int = (seconds / 60) % 60
        let seconds: Int = seconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
