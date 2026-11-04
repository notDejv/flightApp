import SwiftUI

struct LoginView: View {
    private enum Field { case username, password }

    @State private var viewModel: LoginViewModel
    @FocusState private var focusedField: Field?

    init(authService: AuthService, session: SessionStore) {
        _viewModel = State(initialValue: LoginViewModel(authService: authService, session: session))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                header
                form
                Text("Demo login: any username, password of \(MockAuthService.minimumPasswordLength)+ characters.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
            .padding(.top, 48)
        }
        .scrollDismissesKeyboard(.interactively)
        .background { SkyBackground(drifting: true) }
    }

    private var header: some View {
        VStack(spacing: 12) {
            // Flaps hard while signing in, gently otherwise.
            LivelyMascot(flapSpeed: viewModel.isLoading ? 14 : 3, bobAmount: 5)
                .frame(width: 160)
            Text("Wingly")
                .font(.largeTitle.bold())
            Text("Search, save and track your flights.")
                .foregroundStyle(.secondary)
        }
    }

    private var form: some View {
        VStack(spacing: 16) {
            VStack(spacing: 0) {
                TextField("Email or username", text: $viewModel.username)
                    .textContentType(.username)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.next)
                    .focused($focusedField, equals: .username)
                    .onSubmit { focusedField = .password }
                    .padding()
                Divider().padding(.leading)
                SecureField("Password", text: $viewModel.password)
                    .textContentType(.password)
                    .submitLabel(.go)
                    .focused($focusedField, equals: .password)
                    .onSubmit(submit)
                    .padding()
            }
            .background(Palette.card, in: .rect(cornerRadius: 16))
            .shadow(color: Palette.accent.opacity(0.12), radius: 12, y: 6)

            if let error = viewModel.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity)
            }

            Button(action: submit) {
                ZStack {
                    Text("Log In").opacity(viewModel.isLoading ? 0 : 1)
                    if viewModel.isLoading { ProgressView().tint(.white) }
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canSubmit)
        }
        .animation(.default, value: viewModel.errorMessage)
    }

    private func submit() {
        focusedField = nil
        Task { await viewModel.login() }
    }
}

#Preview {
    LoginView(authService: MockAuthService(), session: SessionStore(defaults: UserDefaults(suiteName: "preview")!))
}
