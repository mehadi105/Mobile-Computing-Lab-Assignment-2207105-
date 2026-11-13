import FirebaseAuth
import SwiftUI

struct ContentView: View {
    @StateObject private var auth = AuthViewModel()

    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false

    var body: some View {
        NavigationStack {
            if let user = auth.user {
                TasksView(userID: user.uid, userEmail: user.email ?? "") {
                    auth.signOut()
                }
            } else {
                authForm
            }
        }
    }

    private var authForm: some View {
        VStack(spacing: 20) {
            Text(isSignUp ? "Create Account" : "Sign In")
                .font(.largeTitle)
                .bold()

            Text("Todo List")
                .foregroundStyle(.secondary)

            TextField("Email", text: $email)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)

            SecureField("Password", text: $password)
                .textContentType(isSignUp ? .newPassword : .password)
                .textFieldStyle(.roundedBorder)

            if !auth.errorMessage.isEmpty {
                Text(auth.errorMessage)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Button(isSignUp ? "Sign Up" : "Sign In") {
                Task {
                    if isSignUp {
                        await auth.signUp(email: email, password: password)
                    } else {
                        await auth.signIn(email: email, password: password)
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(auth.isBusy)

            if auth.isBusy {
                ProgressView()
            }

            Button(isSignUp ? "Already have an account? Sign In" : "New user? Sign Up") {
                isSignUp.toggle()
                auth.errorMessage = ""
            }
            .disabled(auth.isBusy)
        }
        .padding()
        .navigationTitle("Firebase Todo")
    }
}
