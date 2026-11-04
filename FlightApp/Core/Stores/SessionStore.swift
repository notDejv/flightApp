import Foundation
import Observation

/// Holds the signed-in user. Mock auth has no token, so the user itself is persisted.
@Observable
@MainActor
final class SessionStore {
    private(set) var user: User? {
        didSet { onUserChange?(user) }
    }

    /// Lets user-scoped state (favorites) follow sign-in and logout synchronously.
    @ObservationIgnored var onUserChange: ((User?) -> Void)?

    private let defaults: UserDefaults
    private let key = "session.user"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        user = defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(User.self, from: $0) }
    }

    var isLoggedIn: Bool { user != nil }

    func signIn(_ user: User) {
        self.user = user
        defaults.set(try? JSONEncoder().encode(user), forKey: key)
    }

    func logout() {
        user = nil
        defaults.removeObject(forKey: key)
    }
}
