import Foundation

struct SyncSnapshot: Codable, Equatable, Sendable {
    var id: UUID
    var createdAt: Date
    var schemaVersion: Int
    var records: [SyncSnapshotRecord]
}

struct SyncSnapshotRecord: Codable, Equatable, Sendable {
    var entityType: String
    var entityID: UUID
    var revision: Int
    var payload: [String: String]
}
