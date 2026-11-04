import Foundation
import Observation

@Observable
@MainActor
final class LoginViewModel {
    var username = ""
    var password = ""
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private let authService: AuthService
    private let session: SessionStore

    init(authService: AuthService, session: SessionStore) {
        self.authService = authService
        self.session = session
    }

    var canSubmit: Bool {
        !username.trimmingCharacters(in: .whitespaces).isEmpty && !password.isEmpty && !isLoading
    }

    func login() async {
        guard canSubmit else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let user = try await authService.login(username: username, password: password)
            session.signIn(user)
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
