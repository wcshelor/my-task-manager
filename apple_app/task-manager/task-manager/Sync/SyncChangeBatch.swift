import Foundation

struct SyncChangeBatch: Codable, Equatable, Sendable {
    var id: UUID
    var deviceID: UUID
    var sequenceNumber: Int
    var createdAt: Date
    var changes: [SyncRecordChange]
}

struct SyncRecordChange: Codable, Equatable, Sendable {
    var entityType: String
    var entityID: UUID
    var operation: SyncOperation
    var changedAt: Date
    var baseRevision: Int?
    var payload: [String: String]
}

enum SyncOperation: String, Codable, Sendable {
    case upsert
    case delete
}
