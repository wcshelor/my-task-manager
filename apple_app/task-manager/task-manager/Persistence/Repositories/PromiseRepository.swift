import Foundation

@MainActor
protocol PromiseRepository {
    func fetchPromises() throws -> [Promise]
    func fetchActivePromises(at date: Date) throws -> [Promise]
    func fetchDuePromises(at date: Date) throws -> [Promise]
    func fetchPromiseHistory() throws -> [Promise]
    func promise(withID id: UUID) throws -> Promise?
    func savePromise(_ promise: Promise, replacingPromiseWithID originalID: UUID?) throws
    func resolvePromise(withID id: UUID, outcome: PromiseOutcome, reflection: String?, resolvedAt: Date) throws
    func deletePromise(withID id: UUID) throws
}
