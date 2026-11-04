import SwiftUI

struct ProfileView: View {
    @Environment(SessionStore.self) private var session
    @Environment(ThemeStore.self) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @State private var isConfirmingLogout = false

    var body: some View {
        NavigationStack {
            List {
                if let user = session.user {
                    Section { userHeader(user) }
                        .cardRows()
                    Section("Account") {
                        LabeledContent("Username", value: user.username)
                        LabeledContent("Email", value: user.email)
                    }
                    .cardRows()
                }

                Section {
                    Toggle("Match System", isOn: matchSystemBinding)
                    Toggle("Dark Mode", isOn: darkModeBinding)
                        .disabled(theme.theme == .system)
                } header: {
                    Text("Appearance")
                } footer: {
                    if theme.theme == .system {
                        Text("Following the system appearance. Turn off Match System to pick one.")
                    }
                }
                .cardRows()

                Section {
                    Button("Log Out", role: .destructive) { isConfirmingLogout = true }
                        .frame(maxWidth: .infinity)
                }
                .cardRows()
            }
            .listStyle(.insetGrouped)
            .skyBackground()
            .navigationTitle("Profile")
            .confirmationDialog("Log out of Wingly?", isPresented: $isConfirmingLogout, titleVisibility: .visible) {
                Button("Log Out", role: .destructive) { session.logout() }
            }
        }
    }

    private func userHeader(_ user: User) -> some View {
        HStack(spacing: 16) {
            Text(user.initials)
                .font(.title2.bold())
                .foregroundStyle(.white)
                .frame(width: 64, height: 64)
                .background(
                    LinearGradient(colors: [Color(hex: 0x8EC5FC), Color(hex: 0xB39DFA)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: .circle
                )
            VStack(alignment: .leading, spacing: 4) {
                Text(user.displayName).font(.title3.bold())
                Text(user.email).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var matchSystemBinding: Binding<Bool> {
        Binding(
            get: { theme.theme == .system },
            set: { matchSystem in
                // Keep whatever is on screen when leaving system mode.
                theme.theme = matchSystem ? .system : (colorScheme == .dark ? .dark : .light)
            }
        )
    }

    private var darkModeBinding: Binding<Bool> {
        Binding(
            get: { theme.theme == .system ? colorScheme == .dark : theme.theme == .dark },
            set: { theme.theme = $0 ? .dark : .light }
        )
    }
}
