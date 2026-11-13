import Combine
import FirebaseAuth

@MainActor
final class AuthViewModel: ObservableObject {
    @Published private(set) var user: User?
    @Published var errorMessage = ""
    @Published private(set) var isBusy = false

    private var authListener: AuthStateDidChangeListenerHandle?

    init() {
        authListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.user = user
            }
        }
    }

    func signUp(email: String, password: String) async {
        await authenticate(email: email, password: password, isSignUp: true)
    }

    func signIn(email: String, password: String) async {
        await authenticate(email: email, password: password, isSignUp: false)
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
            errorMessage = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func authenticate(email: String, password: String, isSignUp: Bool) async {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedEmail.isEmpty, !password.isEmpty else {
            errorMessage = "Enter both email and password."
            return
        }

        isBusy = true
        errorMessage = ""

        do {
            if isSignUp {
                _ = try await Auth.auth().createUser(withEmail: trimmedEmail, password: password)
            } else {
                _ = try await Auth.auth().signIn(withEmail: trimmedEmail, password: password)
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isBusy = false
    }
}
