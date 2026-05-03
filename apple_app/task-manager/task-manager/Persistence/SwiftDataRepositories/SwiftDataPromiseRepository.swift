import Foundation
import SwiftData

@MainActor
final class SwiftDataPromiseRepository: PromiseRepository {
    private let modelContainer: ModelContainer
    private let modelContext: ModelContext

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        self.modelContext = modelContainer.mainContext
    }

    func fetchPromises() throws -> [Promise] {
        try fetchAllRecords()
            .map(\.promise)
            .sorted { leftPromise, rightPromise in
                if leftPromise.startAt != rightPromise.startAt {
                    return leftPromise.startAt < rightPromise.startAt
                }

                return leftPromise.id.uuidString < rightPromise.id.uuidString
            }
    }

    func fetchActivePromises(at date: Date) throws -> [Promise] {
        try fetchPromises().filter { $0.isPresent(at: date) }
    }

    func fetchDuePromises(at date: Date) throws -> [Promise] {
        try fetchPromises().filter { $0.isDueForCheckIn(at: date) }
    }

    func fetchPromiseHistory() throws -> [Promise] {
        try fetchPromises()
            .filter { $0.status == .resolved }
            .sorted { leftPromise, rightPromise in
                let leftResolvedAt = leftPromise.resolvedAt ?? leftPromise.updatedAt
                let rightResolvedAt = rightPromise.resolvedAt ?? rightPromise.updatedAt

                if leftResolvedAt != rightResolvedAt {
                    return leftResolvedAt > rightResolvedAt
                }

                return leftPromise.id.uuidString < rightPromise.id.uuidString
            }
    }

    func promise(withID id: UUID) throws -> Promise? {
        try fetchRecord(withID: id)?.promise
    }

    func savePromise(_ promise: Promise, replacingPromiseWithID originalID: UUID?) throws {
        let record =
            try fetchRecord(withID: originalID ?? promise.id)
            ?? fetchRecord(withID: promise.id)

        if let record {
            record.update(from: promise)
        } else {
            modelContext.insert(PromiseRecord(promise: promise))
        }

        try modelContext.save()
    }

    func resolvePromise(
        withID id: UUID,
        outcome: PromiseOutcome,
        reflection: String?,
        resolvedAt: Date
    ) throws {
        guard let promise = try promise(withID: id) else {
            return
        }

        try savePromise(
            promise.resolved(outcome: outcome, reflection: reflection, resolvedAt: resolvedAt),
            replacingPromiseWithID: id
        )
    }

    func deletePromise(withID id: UUID) throws {
        guard let record = try fetchRecord(withID: id) else {
            return
        }

        modelContext.delete(record)
        try modelContext.save()
    }

    private func fetchAllRecords() throws -> [PromiseRecord] {
        try modelContext.fetch(FetchDescriptor<PromiseRecord>())
    }

    private func fetchRecord(withID id: UUID) throws -> PromiseRecord? {
        try fetchAllRecords().first { $0.id == id }
    }
}
