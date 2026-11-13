import SwiftUI

@MainActor
struct TasksView: View {
    let userID: String
    let userEmail: String
    let onSignOut: () -> Void

    @StateObject private var manager = FirestoreManager()

    @State private var title = ""
    @State private var taskDescription = ""
    @State private var isSaving = false
    @State private var actionError = ""

    @State private var taskToEdit: TodoTask?
    @State private var taskToDelete: TodoTask?
    @State private var showDeleteConfirmation = false

    private var canSaveTask: Bool {
        !isSaving &&
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !taskDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        List {
            Section("New Task") {
                TextField("Title", text: $title)
                TextField("Description", text: $taskDescription, axis: .vertical)
                    .lineLimit(2...4)

                Button(isSaving ? "Saving..." : "Add Task") {
                    Task {
                        await saveTask()
                    }
                }
                .disabled(!canSaveTask)
            }

            Section("My Tasks") {
                if manager.tasks.isEmpty {
                    Text("No tasks yet. Add one above.")
                        .foregroundStyle(.secondary)
                }

                ForEach(manager.tasks) { task in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(task.title)
                            .font(.headline)
                        Text(task.description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button {
                            taskToEdit = task
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.blue)

                        Button(role: .destructive) {
                            taskToDelete = task
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .navigationTitle("My Tasks")
        .navigationSubtitle(userEmail)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Sign Out", role: .destructive) {
                    onSignOut()
                }
            }
        }
        .overlay(alignment: .bottom) {
            if !actionError.isEmpty || !manager.errorMessage.isEmpty {
                Text(actionError.isEmpty ? manager.errorMessage : actionError)
                    .font(.footnote)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.red.gradient, in: Capsule())
                    .padding(.bottom, 8)
            }
        }
        .onAppear {
            manager.startListening(userID: userID)
        }
        .onDisappear {
            manager.stopListening()
        }
        .sheet(item: $taskToEdit) { task in
            EditTaskSheet(task: task, userID: userID, manager: manager)
        }
        .alert(
            "Delete Task?",
            isPresented: $showDeleteConfirmation,
            presenting: taskToDelete
        ) { task in
            Button("Delete", role: .destructive) {
                Task {
                    await deleteTask(task)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { task in
            Text("Permanently delete \"\(task.title)\"?")
        }
    }

    private func saveTask() async {
        isSaving = true
        actionError = ""

        do {
            try await manager.addTask(
                userID: userID,
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                description: taskDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            title = ""
            taskDescription = ""
        } catch {
            actionError = error.localizedDescription
        }

        isSaving = false
    }

    private func deleteTask(_ task: TodoTask) async {
        actionError = ""

        do {
            try await manager.deleteTask(userID: userID, taskID: task.id)
        } catch {
            actionError = error.localizedDescription
        }
    }
}

@MainActor
private struct EditTaskSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var taskDescription: String
    @State private var isSaving = false
    @State private var errorMessage = ""

    let userID: String
    let taskID: String
    let manager: FirestoreManager

    init(task: TodoTask, userID: String, manager: FirestoreManager) {
        self.userID = userID
        self.taskID = task.id
        self.manager = manager
        _title = State(initialValue: task.title)
        _taskDescription = State(initialValue: task.description)
    }

    private var canSaveChanges: Bool {
        !isSaving &&
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !taskDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    TextField("Title", text: $title)
                    TextField("Description", text: $taskDescription, axis: .vertical)
                        .lineLimit(4...8)
                }

                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
            .navigationTitle("Edit Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving..." : "Save") {
                        Task {
                            await saveChanges()
                        }
                    }
                    .disabled(!canSaveChanges)
                }
            }
        }
    }

    private func saveChanges() async {
        let updatedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let updatedDescription = taskDescription.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !updatedTitle.isEmpty, !updatedDescription.isEmpty else {
            return
        }

        isSaving = true
        errorMessage = ""

        do {
            try await manager.updateTask(
                userID: userID,
                taskID: taskID,
                title: updatedTitle,
                description: updatedDescription
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }

        isSaving = false
    }
}
