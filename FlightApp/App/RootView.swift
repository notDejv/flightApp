import SwiftUI

/// Shows the login screen until a user is signed in, then the tabbed app.
struct RootView: View {
    @Environment(AppDependencies.self) private var dependencies
    @Environment(SessionStore.self) private var session
    @Environment(ThemeStore.self) private var theme
    @State private var showsSplash = true

    var body: some View {
        ZStack {
            content
            if showsSplash {
                SplashView {
                    withAnimation(.easeOut(duration: 0.4)) { showsSplash = false }
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .tint(Palette.accent)
        .fontDesign(.rounded)
        .onAppear { theme.apply() }
    }

    private var content: some View {
        ZStack {
            if let user = session.user {
                // Keyed by user so per-user screen state is rebuilt on account switch.
                MainTabView(dependencies: dependencies, user: user)
                    .id(user.id)
                    .transition(.opacity)
            } else {
                LoginView(authService: dependencies.authService, session: session)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.35), value: session.isLoggedIn)
    }
}

#Preview("Logged out") {
    let dependencies = AppDependencies.preview(loggedIn: false)
    RootView()
        .environment(dependencies)
        .environment(dependencies.session)
        .environment(dependencies.theme)
        .environment(dependencies.favorites)
        .environment(dependencies.liveActivities)
}
