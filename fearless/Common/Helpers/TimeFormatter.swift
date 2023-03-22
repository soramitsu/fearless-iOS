enum TimeFormatter {
    static func minutesSecondsString(from seconds: Int) -> String {
        let seconds: Int = seconds % 60
        let minutes: Int = (seconds / 60) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
