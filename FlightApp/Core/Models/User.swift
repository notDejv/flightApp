import Foundation

struct User: Codable, Hashable, Sendable {
    let username: String
    let displayName: String
    let email: String

    /// Owner key for per-user data. Usernames are case-insensitive.
    var id: String { username.lowercased() }

    var initials: String {
        let letters = displayName.split(separator: " ").prefix(2).compactMap(\.first)
        return String(letters).uppercased()
    }
}
