import Foundation

struct SyncManifest: Codable, Equatable, Sendable {
    var schemaVersion: Int
    var folderID: UUID
    var createdAt: Date
    var updatedAt: Date
    var latestSnapshotID: String?

    static func empty(now: Date = .now) -> SyncManifest {
        SyncManifest(
            schemaVersion: 1,
            folderID: UUID(),
            createdAt: now,
            updatedAt: now,
            latestSnapshotID: nil
        )
    }
}
