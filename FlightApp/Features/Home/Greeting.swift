import Foundation

/// Time-of-day greeting for the Home header.
struct Greeting: Equatable {
    let text: String
    let emoji: String

    init(date: Date, calendar: Calendar = .current) {
        switch calendar.component(.hour, from: date) {
        case 5..<12: (text, emoji) = ("Good morning", "☀️")
        case 12..<17: (text, emoji) = ("Good afternoon", "🌤️")
        case 17..<22: (text, emoji) = ("Good evening", "🌙")
        default: (text, emoji) = ("Hey, night owl", "🦉")
        }
    }

    func message(for user: User) -> String {
        let firstName = user.displayName.split(separator: " ").first.map(String.init) ?? user.displayName
        // No-break space keeps the emoji from wrapping onto its own line.
        return "\(text), \(firstName)\u{00A0}\(emoji)"
    }
}
