import Foundation

protocol AuthService: Sendable {
    func login(username: String, password: String) async throws -> User
}

enum AuthError: LocalizedError, Equatable {
    case missingUsername
    case passwordTooShort(minimum: Int)

    var errorDescription: String? {
        switch self {
        case .missingUsername: "Enter your email or username."
        case .passwordTooShort(let minimum): "Password must be at least \(minimum) characters."
        }
    }
}

/// Accepts any username with a password of at least `minimumPasswordLength` characters.
struct MockAuthService: AuthService {
    static let minimumPasswordLength = 4
    var latency: Duration = .milliseconds(500)

    func login(username: String, password: String) async throws -> User {
        let username = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !username.isEmpty else { throw AuthError.missingUsername }
        guard password.count >= Self.minimumPasswordLength else {
            throw AuthError.passwordTooShort(minimum: Self.minimumPasswordLength)
        }

        try await Task.sleep(for: latency)

        let isEmail = username.contains("@")
        // `split` drops empty pieces, so a username of only "@" has no first part.
        let handle = isEmail ? String(username.split(separator: "@").first ?? "") : username
        let displayName = handle
            .split(whereSeparator: { ".-_".contains($0) })
            .map { $0.capitalized }
            .joined(separator: " ")

        return User(
            username: username,
            displayName: displayName.isEmpty ? username : displayName,
            email: isEmail ? username : "\(username.lowercased())@example.com"
        )
    }
}
