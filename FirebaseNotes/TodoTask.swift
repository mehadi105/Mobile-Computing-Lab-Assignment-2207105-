import Foundation

struct TodoTask: Identifiable, Sendable {
    let id: String
    var title: String
    var description: String
    var createdAt: Date
}
