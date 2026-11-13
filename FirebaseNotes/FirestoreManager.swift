import Combine
import FirebaseAuth
import FirebaseFirestore
import Foundation

@MainActor
final class FirestoreManager: ObservableObject {

    @Published private(set) var tasks: [TodoTask] = []
    @Published var errorMessage = ""

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var listenGeneration = 0

    func startListening(userID: String) {
        listener?.remove()
        listener = nil
        tasks = []
        errorMessage = ""

        listenGeneration += 1
        let generation = listenGeneration

        Task {
            if let currentUser = Auth.auth().currentUser {
                _ = try? await currentUser.getIDToken()
            }
            guard generation == listenGeneration else { return }
            attachListener(userID: userID)
        }
    }

    private func attachListener(userID: String) {
        listener = db.collection("users")
            .document(userID)
            .collection("notes")
            .addSnapshotListener { [weak self] snapshot, error in
                if let error {
                    let message = error.localizedDescription
                    Task { @MainActor [weak self] in
                        self?.errorMessage = message
                    }
                    return
                }

                let fetchedTasks: [TodoTask] = snapshot?.documents.compactMap { document in
                    let data = document.data()

                    guard let title = data["title"] as? String else {
                        return nil
                    }

                    let description = (data["description"] as? String)
                        ?? (data["content"] as? String)
                        ?? ""
                    let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? .distantPast

                    return TodoTask(
                        id: document.documentID,
                        title: title,
                        description: description,
                        createdAt: createdAt
                    )
                } ?? []

                let orderedTasks = fetchedTasks.sorted { $0.createdAt > $1.createdAt }

                Task { @MainActor [weak self] in
                    self?.tasks = orderedTasks
                    self?.errorMessage = ""
                }
            }
    }

    func addTask(userID: String, title: String, description: String) async throws {
        let document = db.collection("users")
            .document(userID)
            .collection("notes")
            .document()

        try await document.setData([
            "title": title,
            "description": description,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ])
    }

    func updateTask(
        userID: String,
        taskID: String,
        title: String,
        description: String
    ) async throws {
        let document = db.collection("users")
            .document(userID)
            .collection("notes")
            .document(taskID)

        try await document.updateData([
            "title": title,
            "description": description,
            "updatedAt": FieldValue.serverTimestamp()
        ])
    }

    func deleteTask(userID: String, taskID: String) async throws {
        try await db.collection("users")
            .document(userID)
            .collection("notes")
            .document(taskID)
            .delete()
    }

    func stopListening() {
        listenGeneration += 1
        listener?.remove()
        listener = nil
        tasks = []
    }
}
