import Foundation

struct MyTask: Identifiable, Equatable {
    let id: UUID
    var title: String
    var isDone: Bool
    let createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        isDone: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.isDone = isDone
        self.createdAt = createdAt
    }

    init?(newTitle: String) {
        guard let cleanedTitle = Self.cleanedTitle(from: newTitle) else {
            return nil
        }

        self.init(title: cleanedTitle)
    }

    static let sampleTasks = [
        MyTask(title: "Buy groceries"),
        MyTask(title: "Reply to emails", isDone: true),
        MyTask(title: "Walk the dog")
    ]

    static func cleanedTitle(from rawTitle: String) -> String? {
        let cleanedTitle = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleanedTitle.isEmpty ? nil : cleanedTitle
    }
}

extension Array where Element == MyTask {
    mutating func saveTask(_ task: MyTask, replacingTaskWithID originalID: UUID? = nil) {
        if let originalID, let originalIndex = firstIndex(where: { $0.id == originalID }) {
            self[originalIndex] = task
            return
        }

        if let existingIndex = firstIndex(where: { $0.id == task.id }) {
            self[existingIndex] = task
            return
        }

        append(task)
    }

    mutating func deleteTask(withID id: UUID) {
        removeAll { $0.id == id }
    }

    func containsTask(withID id: UUID, excluding excludedID: UUID? = nil) -> Bool {
        contains { task in
            task.id == id && task.id != excludedID
        }
    }

    func task(withID id: UUID) -> MyTask? {
        first { $0.id == id }
    }
}

//  Task.swift
//  task-manager
//
//  Created by Camp Shelor on 3/26/26.
//
